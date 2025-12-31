# Security Guide for Chat API

Complete guide to API security using rack-attack, rate limiting, and best practices.

---

## 1. rack-attack Overview

rack-attack adalah middleware Rack yang melindungi aplikasi dari:
- **Brute force attacks** (login, registration)
- **Spam** (message flooding)
- **DDoS attacks** (request flooding)
- **Scraping** (data harvesting)
- **API abuse** (excessive requests)

**Cara kerja:**
- Tracks requests by IP, user ID, atau identifier lain
- Throttles requests berdasarkan limit yang ditentukan
- Blocks atau allows requests berdasarkan rules
- Stores data di cache (Redis recommended)

---

## 2. Rate Limiting Strategies

### A. General API Rate Limiting

**Global rate limit** untuk semua requests:

```ruby
# config/initializers/rack_attack.rb

# 60 requests per minute per IP (baseline protection)
throttle('req/ip', limit: 60, period: 1.minute) do |req|
  req.ip unless req.path.start_with?('/admin')
end

# 5000 requests per hour per IP (burst protection)
throttle('req/ip/hour', limit: 5000, period: 1.hour) do |req|
  req.ip
end
```

**Per-user rate limit** (after authentication):

```ruby
# 100 requests per minute per authenticated user
throttle('req/user', limit: 100, period: 1.minute) do |req|
  # Extract user ID from JWT token
  token = req.env['HTTP_AUTHORIZATION']&.split(' ')&.last

  if token
    begin
      decoded = JWT.decode(token, ENV['JWT_SECRET_KEY'], true, algorithm: 'HS256')
      decoded[0]['user_id']
    rescue JWT::DecodeError
      nil
    end
  end
end
```

### B. Authentication Rate Limiting

**Login attempts** (prevent brute force):

```ruby
# 5 login attempts per 20 seconds per email
throttle('logins/email', limit: 5, period: 20.seconds) do |req|
  if req.path == '/api/v1/auth/login' && req.post?
    # Normalize email (lowercase, strip whitespace)
    req.params['email']&.to_s&.downcase&.strip
  end
end

# 10 login attempts per minute per IP (catch distributed attacks)
throttle('logins/ip', limit: 10, period: 1.minute) do |req|
  if req.path == '/api/v1/auth/login' && req.post?
    req.ip
  end
end

# 50 failed logins per hour per IP (long-term protection)
throttle('logins/ip/hour', limit: 50, period: 1.hour) do |req|
  if req.path == '/api/v1/auth/login' && req.post?
    req.ip
  end
end
```

**Registration limits** (prevent spam accounts):

```ruby
# 3 registrations per 5 minutes per IP
throttle('registrations/ip', limit: 3, period: 5.minutes) do |req|
  if req.path == '/api/v1/auth/register' && req.post?
    req.ip
  end
end

# 1 registration per email per hour (prevent retry spam)
throttle('registrations/email', limit: 1, period: 1.hour) do |req|
  if req.path == '/api/v1/auth/register' && req.post?
    req.params['email']&.downcase
  end
end
```

**Password reset** (prevent abuse):

```ruby
# 3 password reset requests per hour per email
throttle('password_reset/email', limit: 3, period: 1.hour) do |req|
  if req.path == '/api/v1/auth/reset_password' && req.post?
    req.params['email']&.downcase
  end
end

# 10 password reset attempts per hour per IP
throttle('password_reset/ip', limit: 10, period: 1.hour) do |req|
  if req.path == '/api/v1/auth/reset_password' && req.post?
    req.ip
  end
end
```

### C. Chat-Specific Rate Limiting

**Message creation** (prevent spam):

```ruby
# 30 messages per minute per user (normal usage)
throttle('messages/user', limit: 30, period: 1.minute) do |req|
  if req.path.match?(/\/api\/v1\/conversations\/\d+\/messages/) && req.post?
    # Extract user ID from JWT
    extract_user_id_from_jwt(req)
  end
end

# 10 messages per minute to same conversation (prevent flooding)
throttle('messages/conversation/user', limit: 10, period: 1.minute) do |req|
  if req.path.match?(/\/api\/v1\/conversations\/(\d+)\/messages/) && req.post?
    conversation_id = $1
    user_id = extract_user_id_from_jwt(req)
    "#{user_id}:#{conversation_id}" if user_id
  end
end

# 100 messages per hour per user (long-term limit)
throttle('messages/user/hour', limit: 100, period: 1.hour) do |req|
  if req.path.match?(/\/api\/v1\/conversations\/\d+\/messages/) && req.post?
    extract_user_id_from_jwt(req)
  end
end
```

**Conversation creation** (prevent spam groups):

```ruby
# 5 conversations per hour per user
throttle('conversations/user', limit: 5, period: 1.hour) do |req|
  if req.path == '/api/v1/conversations' && req.post?
    extract_user_id_from_jwt(req)
  end
end

# 10 group chats per day per user
throttle('group_chats/user', limit: 10, period: 1.day) do |req|
  if req.path == '/api/v1/conversations' && req.post? && req.params['type'] == 'GroupChat'
    extract_user_id_from_jwt(req)
  end
end
```

**File uploads** (prevent storage abuse):

```ruby
# 20 file uploads per hour per user
throttle('uploads/user', limit: 20, period: 1.hour) do |req|
  if req.path == '/api/v1/media/upload' && req.post?
    extract_user_id_from_jwt(req)
  end
end

# 50MB total uploads per hour per user (combined with application logic)
# Note: This requires custom tracking in application code
```

**Reactions** (prevent spam reactions):

```ruby
# 30 reactions per minute per user
throttle('reactions/user', limit: 30, period: 1.minute) do |req|
  if req.path.match?(/\/api\/v1\/messages\/\d+\/reactions/) && req.post?
    extract_user_id_from_jwt(req)
  end
end
```

### D. Search Rate Limiting

```ruby
# 20 search queries per minute per user
throttle('search/user', limit: 20, period: 1.minute) do |req|
  if req.path.include?('/search') && req.get?
    extract_user_id_from_jwt(req)
  end
end

# 5 search queries per 10 seconds per IP (unauthenticated)
throttle('search/ip', limit: 5, period: 10.seconds) do |req|
  if req.path.include?('/search') && req.get?
    req.ip
  end
end
```

---

## 3. Blocklist & Safelist

### Blocklist (Block specific IPs or patterns)

```ruby
# Block known bad IPs
blocklist('block bad IPs') do |req|
  # Store blocked IPs in Redis or database
  bad_ips = $redis.smembers('blocked_ips')
  bad_ips.include?(req.ip)
end

# Block based on User-Agent (block bots)
blocklist('block bad user agents') do |req|
  bad_agents = ['BadBot', 'Scraper', 'curl'] # Update based on needs
  bad_agents.any? { |agent| req.user_agent.to_s.include?(agent) }
end

# Block requests without User-Agent (suspicious)
blocklist('require user agent') do |req|
  !req.path.start_with?('/admin') && req.user_agent.blank?
end

# Block based on country (optional - requires GeoIP)
blocklist('block by country') do |req|
  # Requires gem 'maxmind-geoip2'
  # blocked_countries = ['XX', 'YY']
  # country = GeoIP.lookup(req.ip)&.country_code
  # blocked_countries.include?(country)
  false # Disabled by default
end
```

### Safelist (Allow specific IPs or patterns)

```ruby
# Allow internal IPs (office, CI/CD)
safelist('allow internal IPs') do |req|
  internal_ips = [
    '127.0.0.1',
    '::1',
    '192.168.0.0/16',
    '10.0.0.0/8',
    ENV['OFFICE_IP']
  ].compact

  internal_ips.any? do |range|
    IPAddr.new(range).include?(IPAddr.new(req.ip))
  rescue IPAddr::InvalidAddressError
    req.ip == range
  end
end

# Allow healthcheck endpoints (monitoring services)
safelist('allow healthchecks') do |req|
  req.path == '/up' || req.path == '/health'
end

# Allow admin panel (assuming separate auth)
safelist('allow admin') do |req|
  req.path.start_with?('/admin') || req.path.start_with?('/flipper')
end
```

---

## 4. Custom Responses

### Custom Throttle Response

```ruby
# Return JSON with retry information
Rack::Attack.throttled_responder = lambda do |env|
  match_data = env['rack.attack.match_data']
  now = Time.current
  retry_after = match_data[:period] - (now.to_i % match_data[:period])

  [
    429, # Too Many Requests
    {
      'Content-Type' => 'application/json',
      'Retry-After' => retry_after.to_s,
      'X-RateLimit-Limit' => match_data[:limit].to_s,
      'X-RateLimit-Remaining' => '0',
      'X-RateLimit-Reset' => (now + retry_after).to_i.to_s
    },
    [{
      success: false,
      error: 'Rate limit exceeded. Too many requests.',
      retry_after: retry_after,
      limit: match_data[:limit],
      period: match_data[:period]
    }.to_json]
  ]
end
```

### Custom Block Response

```ruby
# Return JSON for blocked requests
Rack::Attack.blocklisted_responder = lambda do |env|
  [
    403, # Forbidden
    {
      'Content-Type' => 'application/json'
    },
    [{
      success: false,
      error: 'Forbidden. Your request has been blocked.'
    }.to_json]
  ]
end
```

---

## 5. Logging & Monitoring

### ActiveSupport Notifications

```ruby
# Log all rack-attack events
ActiveSupport::Notifications.subscribe('rack.attack') do |name, start, finish, request_id, payload|
  req = payload[:request]
  match_type = req.env['rack.attack.match_type']

  case match_type
  when :throttle
    # Log throttled requests
    Rails.logger.warn({
      event: 'rack_attack_throttle',
      ip: req.ip,
      path: req.path,
      matched: req.env['rack.attack.matched'],
      discriminator: req.env['rack.attack.match_discriminator']
    }.to_json)

  when :blocklist
    # Log blocked requests (high priority)
    Rails.logger.error({
      event: 'rack_attack_block',
      ip: req.ip,
      path: req.path,
      user_agent: req.user_agent,
      matched: req.env['rack.attack.matched']
    }.to_json)

  when :safelist
    # Optional: Log safelisted requests
    # Rails.logger.info(...)
  end
end
```

### Send Alerts (Production)

```ruby
# Send alerts for suspicious activity
ActiveSupport::Notifications.subscribe('rack.attack') do |name, start, finish, request_id, payload|
  req = payload[:request]

  if req.env['rack.attack.match_type'] == :blocklist
    # Send alert to Slack, PagerDuty, etc.
    AlertService.notify(
      channel: '#security',
      message: "🚨 Blocked request from #{req.ip} to #{req.path}"
    )
  end

  # Track repeated offenders
  if req.env['rack.attack.match_type'] == :throttle
    offender_key = "rack_attack:offender:#{req.ip}"
    count = $redis.incr(offender_key)
    $redis.expire(offender_key, 1.hour)

    if count > 10 # 10 throttles in 1 hour
      # Automatically blocklist
      $redis.sadd('blocked_ips', req.ip)

      AlertService.notify(
        channel: '#security',
        message: "⚠️  Auto-blocked IP #{req.ip} after #{count} rate limit violations"
      )
    end
  end
end
```

---

## 6. Dynamic Configuration

### Environment-based Limits

```ruby
# config/initializers/rack_attack.rb

# Load limits from environment variables
DEFAULT_RATE_LIMIT = ENV.fetch('RATE_LIMIT_PER_MINUTE', 60).to_i
LOGIN_ATTEMPTS = ENV.fetch('LOGIN_ATTEMPTS_LIMIT', 5).to_i
MESSAGE_LIMIT = ENV.fetch('MESSAGE_LIMIT_PER_MINUTE', 30).to_i

throttle('req/ip', limit: DEFAULT_RATE_LIMIT, period: 1.minute) do |req|
  req.ip
end

throttle('logins/email', limit: LOGIN_ATTEMPTS, period: 20.seconds) do |req|
  if req.path == '/api/v1/auth/login' && req.post?
    req.params['email']&.downcase
  end
end

throttle('messages/user', limit: MESSAGE_LIMIT, period: 1.minute) do |req|
  if req.path.match?(/\/api\/v1\/conversations\/\d+\/messages/) && req.post?
    extract_user_id_from_jwt(req)
  end
end
```

### Database-based Configuration (Advanced)

```ruby
# Store limits in database, refresh periodically
class RateLimitConfig < ApplicationRecord
  # table: rate_limit_configs
  # columns: name, limit, period_seconds
end

# Refresh every 5 minutes
RATE_LIMITS = Rails.cache.fetch('rate_limits', expires_in: 5.minutes) do
  RateLimitConfig.all.each_with_object({}) do |config, hash|
    hash[config.name] = { limit: config.limit, period: config.period_seconds }
  end
end

# Use in throttle
throttle('dynamic/messages') do |req|
  limit_config = RATE_LIMITS['messages'] || { limit: 30, period: 60 }

  if req.path.match?(/\/messages/) && req.post?
    { limit: limit_config[:limit], period: limit_config[:period].seconds }
  end
end
```

---

## 7. Helper Methods

### Extract User ID from JWT

```ruby
# config/initializers/rack_attack.rb

def self.extract_user_id_from_jwt(req)
  token = req.env['HTTP_AUTHORIZATION']&.split(' ')&.last
  return nil unless token

  begin
    decoded = JWT.decode(token, ENV['JWT_SECRET_KEY'], true, algorithm: 'HS256')
    decoded[0]['user_id']
  rescue JWT::DecodeError, JWT::ExpiredSignature
    nil
  end
end

# Use in throttles
throttle('messages/user', limit: 30, period: 1.minute) do |req|
  if req.path.match?(/\/messages/) && req.post?
    Rack::Attack.extract_user_id_from_jwt(req)
  end
end
```

### IP Address Utilities

```ruby
# config/initializers/rack_attack.rb

def self.internal_ip?(ip)
  internal_ranges = [
    IPAddr.new('127.0.0.1'),
    IPAddr.new('::1'),
    IPAddr.new('10.0.0.0/8'),
    IPAddr.new('172.16.0.0/12'),
    IPAddr.new('192.168.0.0/16')
  ]

  internal_ranges.any? { |range| range.include?(IPAddr.new(ip)) }
rescue IPAddr::InvalidAddressError
  false
end
```

---

## 8. Testing rack-attack

### RSpec Tests

```ruby
# spec/requests/rate_limiting_spec.rb
require 'rails_helper'

RSpec.describe 'Rate Limiting', type: :request do
  describe 'General API rate limit' do
    it 'throttles excessive requests from same IP' do
      # Make 60 requests (under limit)
      60.times do
        get '/api/v1/ping'
        expect(response).to have_http_status(:ok)
      end

      # 61st request should be throttled
      get '/api/v1/ping'
      expect(response).to have_http_status(429)
      expect(response.body).to include('Too many requests')
    end
  end

  describe 'Login rate limit' do
    it 'throttles login attempts by email' do
      # Make 5 attempts (limit)
      5.times do
        post '/api/v1/auth/login', params: { email: 'test@example.com', password: 'wrong' }
      end

      # 6th attempt should be throttled
      post '/api/v1/auth/login', params: { email: 'test@example.com', password: 'wrong' }
      expect(response).to have_http_status(429)
    end

    it 'does not throttle different emails' do
      5.times do |i|
        post '/api/v1/auth/login', params: { email: "user#{i}@example.com", password: 'wrong' }
        expect(response).not_to have_http_status(429)
      end
    end
  end
end
```

### Manual Testing

```bash
# Test rate limiting with curl

# Test general rate limit (60 req/min)
for i in {1..61}; do
  curl -s http://localhost:3000/api/v1/ping | jq .
  sleep 0.1
done

# Test login throttling
for i in {1..6}; do
  curl -X POST http://localhost:3000/api/v1/auth/login \
    -H "Content-Type: application/json" \
    -d '{"email":"test@example.com","password":"wrong"}' | jq .
done

# Test with different IPs (using X-Forwarded-For)
curl -H "X-Forwarded-For: 1.2.3.4" http://localhost:3000/api/v1/ping
```

---

## 9. Production Best Practices

### 1. Use Redis for Cache

```ruby
# config/initializers/rack_attack.rb
Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(
  url: ENV.fetch('REDIS_URL') { 'redis://localhost:6379/1' },
  pool_size: 10,
  pool_timeout: 5
)
```

**Why Redis?**
- Fast, in-memory storage
- Handles high request volumes
- Supports TTL (automatic expiration)
- Shared across multiple app servers

### 2. Monitor & Alert

```ruby
# Send metrics to monitoring service
ActiveSupport::Notifications.subscribe('rack.attack') do |name, start, finish, request_id, payload|
  req = payload[:request]

  # Send to StatsD, DataDog, New Relic, etc.
  StatsD.increment('rack_attack.throttle') if req.env['rack.attack.match_type'] == :throttle
  StatsD.increment('rack_attack.blocklist') if req.env['rack.attack.match_type'] == :blocklist
end
```

### 3. Gradual Rollout (Feature Flags)

```ruby
# Use Flipper to enable/disable rack-attack rules
throttle('messages/user', limit: 30, period: 1.minute) do |req|
  if Flipper.enabled?(:rate_limit_messages) && req.path.match?(/\/messages/) && req.post?
    extract_user_id_from_jwt(req)
  end
end
```

### 4. IP Reputation Services (Optional)

```ruby
# Integrate with IP reputation APIs
blocklist('block malicious IPs') do |req|
  # Check against IP reputation database
  IpReputationService.is_malicious?(req.ip)
end
```

### 5. Cloudflare / CDN Integration

If using Cloudflare:
- Enable rate limiting at CDN level (first line of defense)
- Use rack-attack for application-level protection
- Trust Cloudflare IPs:

```ruby
# config/initializers/rack_attack.rb
class Rack::Attack
  # Get real IP from Cloudflare headers
  class Request < ::Rack::Request
    def ip
      @ip ||= env['HTTP_CF_CONNECTING_IP'] ||
              env['HTTP_X_FORWARDED_FOR']&.split(',')&.first&.strip ||
              env['REMOTE_ADDR']
    end
  end
end
```

---

## 10. Emergency Response

### Manually Block IPs

```bash
# Rails console
rails console

# Block IP immediately
$redis.sadd('blocked_ips', '1.2.3.4')

# Unblock IP
$redis.srem('blocked_ips', '1.2.3.4')

# List all blocked IPs
$redis.smembers('blocked_ips')
```

### Temporarily Increase Limits

```ruby
# Rails console
ENV['RATE_LIMIT_PER_MINUTE'] = '120'

# Restart server for changes to take effect
# Or use dynamic configuration from database
```

### Disable rack-attack (Emergency)

```ruby
# config/initializers/rack_attack.rb
# Comment out or wrap in conditional:

if ENV['RACK_ATTACK_ENABLED'] != 'false'
  Rails.application.config.middleware.use Rack::Attack
end

# Then set environment variable:
# RACK_ATTACK_ENABLED=false
```

---

## Summary

**Essential Protection:**
- ✅ General API rate limiting (60 req/min per IP)
- ✅ Login throttling (5 attempts per 20s per email)
- ✅ Registration limits (3 per 5min per IP)
- ✅ Message spam prevention (30 per min per user)
- ✅ File upload limits (20 per hour per user)

**Recommended Setup:**
- Use Redis for cache storage
- Enable logging and monitoring
- Set up alerts for suspicious activity
- Test thoroughly before production
- Use environment variables for configuration

**Emergency Tools:**
- Manual IP blocking via Redis
- Feature flags to disable rules
- Dynamic limit adjustment
- Cloudflare backup protection

---

**Stay Safe! 🔒**

Jika ada pertanyaan atau butuh custom rate limiting rules, jangan ragu untuk bertanya!
