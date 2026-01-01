# Chat API - Configuration Guide

Advanced configuration for CORS, Redis, Sidekiq, API structure, security, and monitoring.

**Prerequisites:** Complete the [Installation Guide](installation.md) first.

---

## Phase 4: Configure CORS (Trunk-Based Development)

CORS (Cross-Origin Resource Sharing) allows your frontend to communicate with your Rails API. We use environment variables for configuration to support Trunk-Based Development.

**What is CORS?**
- Browser security mechanism that controls which domains can access your API
- Without CORS, your React/Vue/Angular frontend can't call your Rails API
- Required for any API consumed by web browsers

### Step 4.1: Create CORS Initializer

```bash
# Edit config/initializers/cors.rb
code config/initializers/cors.rb
```

**Replace with simplified environment-based configuration:**
```ruby
# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # Read allowed origins from environment variable
    # Supports multiple origins separated by comma
    allowed_origins = ENV.fetch('CORS_ORIGINS', '').split(',').map(&:strip)

    # Fallback to wildcard in development if not configured
    if allowed_origins.empty?
      if Rails.env.development?
        allowed_origins = '*'
        Rails.logger.info "CORS: Using wildcard (*) - development mode"
      else
        # Production requires explicit configuration
        raise "CORS_ORIGINS environment variable is required in #{Rails.env} environment"
      end
    else
      Rails.logger.info "CORS: Allowed origins - #{allowed_origins.join(', ')}"
    end

    origins allowed_origins

    # Hardcoded settings (rarely change, simplifies configuration)
    resource '/api/*',
      headers: %w[Authorization Content-Type Accept X-Requested-With],
      methods: %i[get post put patch delete options head],
      expose: %w[Authorization X-Total-Count X-Page],
      credentials: true,
      max_age: 86400  # 24 hours
  end
end
```

**Why simplified?**
- ✅ Only `CORS_ORIGINS` varies between environments
- ✅ Other settings (headers, methods, etc.) rarely change
- ✅ Easier to understand and maintain
- ✅ Less configuration to manage
- ✅ Still follows 12-factor app best practices

### Step 4.2: Create CORS Validator (Optional but Recommended)

```bash
# Create validator
touch config/initializers/cors_validator.rb
code config/initializers/cors_validator.rb
```

**Add validation:**
```ruby
# config/initializers/cors_validator.rb
Rails.application.config.after_initialize do
  # Skip validation in test environment
  next if Rails.env.test?

  cors_origins = ENV.fetch('CORS_ORIGINS', '')

  # Validate in production
  if Rails.env.production?
    if cors_origins.blank?
      Rails.logger.error "❌ CORS ERROR: CORS_ORIGINS is not configured for production!"
      raise "CORS_ORIGINS environment variable is required in production"
    end

    if cors_origins.include?('*')
      Rails.logger.error "❌ CORS ERROR: Wildcard (*) is not allowed in production!"
      raise "CORS_ORIGINS cannot use wildcard (*) in production"
    end

    if cors_origins.include?('localhost')
      Rails.logger.warn "⚠️  CORS WARNING: localhost detected in production CORS_ORIGINS"
    end

    Rails.logger.info "✅ CORS: Configured for #{cors_origins.split(',').count} origin(s)"
  end

  # Info in development
  if Rails.env.development?
    if cors_origins.blank?
      Rails.logger.info "ℹ️  CORS: Using wildcard (*) for development (CORS_ORIGINS not set)"
    else
      Rails.logger.info "✅ CORS: Configured for #{cors_origins.split(',').count} origin(s)"
    end
  end
end
```

### Step 4.3: Configure Environment Variables

**Add to .env file:**
```bash
# Edit .env
code .env
```

**Add CORS configuration:**
```bash
# ============================================
# CORS Configuration
# ============================================
# Comma-separated list of allowed origins
# Development: Use localhost ports where your frontend runs (React, Vue, etc.)
# Example: React (Vite) runs on 5173, Create React App on 3000
CORS_ORIGINS=http://localhost:5173,http://localhost:3000,http://localhost:8080
```

**That's it! Just one environment variable.**

All other CORS settings (headers, methods, credentials) are hardcoded in the initializer because they rarely change.

### Step 4.4: Update .env.example

**Add to .env.example:**
```bash
# Edit .env.example
code .env.example
```

**Add CORS section:**
```bash
# ============================================
# CORS Configuration
# ============================================
# Comma-separated list of allowed origins
# Development: localhost with various ports (React Vite: 5173, CRA: 3000, etc.)
# Staging: https://staging.myapp.com
# Production: https://myapp.com,https://www.myapp.com
CORS_ORIGINS=http://localhost:5173,http://localhost:3000
```

### Step 4.5: Environment-Specific Configuration

**For different environments, set CORS_ORIGINS:**

**Development (.env):**
```bash
# Local development - allow multiple localhost ports
CORS_ORIGINS=http://localhost:5173,http://localhost:3000,http://localhost:8080,http://127.0.0.1:5173
```

**Staging (hosting platform environment variables):**
```bash
# Staging environment - your staging frontend domain(s)
CORS_ORIGINS=https://staging.myapp.com,https://staging-mobile.myapp.com
```

**Production (hosting platform environment variables):**
```bash
# Production - only production frontend domain(s)
CORS_ORIGINS=https://myapp.com,https://www.myapp.com,https://mobile.myapp.com
```

**Common frontend frameworks and their default ports:**
- React (Vite): `http://localhost:5173`
- React (Create React App): `http://localhost:3000`
- Vue (Vite): `http://localhost:5173`
- Angular: `http://localhost:4200`
- Next.js: `http://localhost:3000`
- Nuxt.js: `http://localhost:3000`

### Step 4.6: Test CORS Configuration

**Start Rails server:**
```bash
rails s
```

**Test CORS with curl:**
```bash
# Test preflight request
curl -H "Origin: http://localhost:5173" \
     -H "Access-Control-Request-Method: POST" \
     -H "Access-Control-Request-Headers: Authorization" \
     -X OPTIONS \
     -v \
     http://localhost:3000/api/v1/ping

# Should return CORS headers:
# Access-Control-Allow-Origin: http://localhost:5173
# Access-Control-Allow-Methods: get, post, put, patch, delete, options, head
# Access-Control-Allow-Headers: Authorization, Content-Type, Accept
```

**Test from browser console:**
```javascript
// Open your frontend in browser, then open console (F12)
fetch('http://localhost:3000/api/v1/ping')
  .then(res => res.json())
  .then(data => console.log('✅ CORS working:', data))
  .catch(err => console.error('❌ CORS error:', err));
```

### Step 4.7: CORS Configuration Reference

**Configurable via environment variables:**

| Variable | Description | Example |
|----------|-------------|---------|
| `CORS_ORIGINS` | Comma-separated allowed domains | `https://myapp.com,https://mobile.myapp.com` |

**Hardcoded in initializer (config/initializers/cors.rb):**

| Setting | Value | Why Hardcoded? |
|---------|-------|----------------|
| `resource` | `/api/*` | API path never changes |
| `headers` | `Authorization`, `Content-Type`, `Accept`, `X-Requested-With` | Standard headers for JWT auth |
| `methods` | `GET`, `POST`, `PUT`, `PATCH`, `DELETE`, `OPTIONS`, `HEAD` | Standard REST methods |
| `expose` | `Authorization`, `X-Total-Count`, `X-Page` | Standard response headers for pagination |
| `credentials` | `true` | Required for JWT authentication |
| `max_age` | `86400` (24 hours) | Reasonable cache duration |

**When to make more settings configurable:**
- Only add environment variables if you **actually need** different values per environment
- For 95% of apps, only `CORS_ORIGINS` varies
- Keep it simple unless you have a specific requirement

**Deployment platforms:**

**Heroku:**
```bash
# Staging
heroku config:set CORS_ORIGINS="https://staging.myapp.com" --app myapp-staging

# Production
heroku config:set CORS_ORIGINS="https://myapp.com,https://www.myapp.com" --app myapp-production
```

**Railway/Render:**
Add environment variables in the dashboard UI.

**Docker:**
```yaml
# docker-compose.yml
services:
  api:
    environment:
      - CORS_ORIGINS=https://myapp.com
```

**Security notes:**
- ✅ Simple configuration - only origins are environment-specific
- ✅ Same code runs in all environments (Trunk-Based Development)
- ✅ Production requires explicit origins (no wildcard `*`)
- ✅ Validates configuration on startup
- ✅ Logs CORS configuration for debugging
- ✅ Secure defaults (credentials enabled for JWT auth)

**Common CORS errors and solutions:**

| Error | Cause | Solution |
|-------|-------|----------|
| "No 'Access-Control-Allow-Origin' header" | CORS not configured or wrong origin | Add frontend URL to `CORS_ORIGINS` |
| "Credentials flag is true, but origin is '*'" | Development mode with no `CORS_ORIGINS` set | Set `CORS_ORIGINS` in `.env` or keep wildcard for local dev |
| "Origin not allowed" | Frontend URL not in `CORS_ORIGINS` | Add your frontend URL to `CORS_ORIGINS` (comma-separated) |
| "CORS_ORIGINS environment variable is required" | Production without `CORS_ORIGINS` set | Set `CORS_ORIGINS` in hosting platform environment variables |

**Need to add more headers or methods?**
Edit `config/initializers/cors.rb` directly:
```ruby
# Add custom header
headers: %w[Authorization Content-Type Accept X-Requested-With X-Custom-Header]

# Add custom method
methods: %i[get post put patch delete options head custom]
```
This is rare but supported if needed.

---

## Phase 5: Setup Redis & Sidekiq

### Step 5.1: Configure Redis

```bash
# Create config/initializers/redis.rb
touch config/initializers/redis.rb
code config/initializers/redis.rb
```

**Add:**
```ruby
# config/initializers/redis.rb
redis_url = ENV.fetch('REDIS_URL') { 'redis://localhost:6379/0' }

$redis = Redis.new(url: redis_url)

# Test connection
begin
  $redis.ping
  Rails.logger.info "Redis connected successfully"
rescue Redis::CannotConnectError => e
  Rails.logger.error "Redis connection failed: #{e.message}"
end
```

### Step 5.2: Configure Sidekiq

```bash
# Create config/sidekiq.yml
touch config/sidekiq.yml
code config/sidekiq.yml
```

**Add:**
```yaml
# config/sidekiq.yml
:concurrency: 5
:queues:
  - default
  - mailers
  - notifications
  - media_processing

development:
  :concurrency: 2

production:
  :concurrency: 10
```

**Create config/initializers/sidekiq.rb:**
```bash
touch config/initializers/sidekiq.rb
code config/initializers/sidekiq.rb
```

**Add:**
```ruby
# config/initializers/sidekiq.rb
Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch('REDIS_URL') { 'redis://localhost:6379/0' } }
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch('REDIS_URL') { 'redis://localhost:6379/0' } }
end
```

---

## Phase 6: Setup API Structure

### Step 6.1: Create API Base Controller

```bash
# Create API directory
mkdir -p app/controllers/api/v1

# Create base controller
touch app/controllers/api/v1/base_controller.rb
code app/controllers/api/v1/base_controller.rb
```

**Add:**
```ruby
# app/controllers/api/v1/base_controller.rb
module Api
  module V1
    class BaseController < ApplicationController
      # Disable CSRF for API
      skip_before_action :verify_authenticity_token

      # JSON response helpers
      def render_success(data, status: :ok)
        render json: { success: true, data: data }, status: status
      end

      def render_error(message, status: :bad_request)
        render json: { success: false, error: message }, status: status
      end

      # Error handling
      rescue_from ActiveRecord::RecordNotFound do |e|
        render_error(e.message, status: :not_found)
      end

      rescue_from ActiveRecord::RecordInvalid do |e|
        render_error(e.message, status: :unprocessable_entity)
      end
    end
  end
end
```

### Step 6.2: Setup Routes

```bash
# Edit config/routes.rb
code config/routes.rb
```

**Add API routes (keep existing Rswag routes!):**

The file already has Rswag routes mounted. Just **add** the API namespace:

```ruby
# config/routes.rb
Rails.application.routes.draw do
  # Rswag API Documentation (already exists - don't remove!)
  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'

  # Health check endpoint (already exists)
  get "up" => "rails/health#show", as: :rails_health_check

  # API routes (ADD THIS)
  namespace :api do
    namespace :v1 do
      # Authentication routes (will be created later)
      # namespace :auth do
      #   post 'register'
      #   post 'login'
      #   delete 'logout'
      #   post 'refresh'
      #   get 'me'
      # end

      # Test endpoint
      get 'ping', to: 'ping#index'
    end
  end
end
```

**Note:** More routes will be added in later steps (Flipper UI, ActiveAdmin).

### Step 6.3: Create Test Endpoint

```bash
# Create ping controller
touch app/controllers/api/v1/ping_controller.rb
code app/controllers/api/v1/ping_controller.rb
```

**Add:**
```ruby
# app/controllers/api/v1/ping_controller.rb
module Api
  module V1
    class PingController < BaseController
      def index
        render_success({
          message: 'pong',
          timestamp: Time.current,
          version: 'v1'
        })
      end
    end
  end
end
```

### Step 6.4: Setup Blueprint Serializers

Blueprint is the serializer we'll use to convert models into JSON responses.

```bash
# Create blueprints directory
mkdir -p app/blueprints

# Create base blueprint
touch app/blueprints/application_blueprint.rb
code app/blueprints/application_blueprint.rb
```

**Add:**
```ruby
# app/blueprints/application_blueprint.rb
class ApplicationBlueprint < Blueprinter::Base
  # Default datetime format
  def self.datetime_format
    ->(datetime) { datetime&.iso8601 }
  end
end
```

**Create example blueprint for testing:**
```bash
# Create ping blueprint
touch app/blueprints/ping_blueprint.rb
code app/blueprints/ping_blueprint.rb
```

**Add:**
```ruby
# app/blueprints/ping_blueprint.rb
class PingBlueprint < ApplicationBlueprint
  fields :message, :version

  field :timestamp do |_object, options|
    options[:timestamp]
  end
end
```

**Update ping controller to use Blueprint:**
```bash
code app/controllers/api/v1/ping_controller.rb
```

**Update to:**
```ruby
# app/controllers/api/v1/ping_controller.rb
module Api
  module V1
    class PingController < BaseController
      def index
        data = {
          message: 'pong',
          version: 'v1'
        }

        # Using Blueprint
        json = PingBlueprint.render_as_hash(
          data,
          timestamp: Time.current
        )

        render_success(json)
      end
    end
  end
end
```

**Configure Blueprinter (optional):**
```bash
# Create initializer
touch config/initializers/blueprinter.rb
code config/initializers/blueprinter.rb
```

**Add:**
```ruby
# config/initializers/blueprinter.rb
require 'blueprinter'

Blueprinter.configure do |config|
  config.generator = Oj # Use Oj for faster JSON generation
  config.datetime_format = ->(datetime) { datetime&.iso8601 }
  config.sort_fields_by = :definition # Keep field order as defined
end
```

### Step 6.5: Setup Flipper (Feature Flags)

Flipper enables Trunk-Based Development with feature flags.

```bash
# Generate Flipper migration
rails generate flipper:active_record

# Run migration
rails db:migrate

# Expected output:
# ==  CreateFlipperTables: migrating ===================
# -- create_table(:flipper_features)
# -- create_table(:flipper_gates)
# ==  CreateFlipperTables: migrated
```

**Create Flipper initializer:**
```bash
touch config/initializers/flipper.rb
code config/initializers/flipper.rb
```

**Add:**
```ruby
# config/initializers/flipper.rb
require 'flipper'
require 'flipper/adapters/active_record'

Flipper.configure do |config|
  config.adapter { Flipper::Adapters::ActiveRecord.new }
end

# Preload features (optional, for performance)
Flipper.preload_all
```

**Mount Flipper UI (for admins):**
```bash
# Edit config/routes.rb
code config/routes.rb
```

**Add Flipper UI route to your existing routes.rb:**
```ruby
# config/routes.rb
Rails.application.routes.draw do
  # Rswag API Documentation
  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'

  # Health check endpoint
  get "up" => "rails/health#show", as: :rails_health_check

  # Flipper UI (ADD THIS - for development only)
  if Rails.env.development?
    mount Flipper::UI.app(Flipper) => '/flipper'
  end

  # API routes
  namespace :api do
    namespace :v1 do
      get 'ping', to: 'ping#index'
    end
  end
end
```

**Test Flipper:**
```bash
# Rails console
rails console

# Create a feature flag
Flipper.enable(:test_feature)

# Check if enabled
Flipper.enabled?(:test_feature)
# => true

# Disable
Flipper.disable(:test_feature)

# Check again
Flipper.enabled?(:test_feature)
# => false

# Exit
exit
```

**Access Flipper UI:**
- Start Rails server (`rails s`)
- Visit: `http://localhost:3000/flipper`
- You'll see the Flipper dashboard where you can manage feature flags

**Example usage in controller:**
```ruby
# app/controllers/api/v1/ping_controller.rb
def index
  data = {
    message: 'pong',
    version: 'v1',
    timestamp: Time.current
  }

  # Add experimental feature behind flag
  if Flipper.enabled?(:show_server_stats)
    data[:server_stats] = {
      uptime: `uptime`,
      load: `cat /proc/loadavg`
    }
  end

  render_success(data)
end
```

### Step 6.6: Setup ActiveAdmin (Admin Panel)

ActiveAdmin provides admin dashboard for user management, moderation, and customer support.

```bash
# Generate ActiveAdmin installation
rails generate active_admin:install

# This will:
# - Create config/initializers/active_admin.rb
# - Create app/admin/ directory
# - Install Devise for authentication
# - Create AdminUser model
# - Add routes

# Run migrations
rails db:migrate

# Expected output:
# ==  DeviseCreateAdminUsers: migrating ===================
# -- create_table(:admin_users)
# ==  CreateActiveAdminComments: migrating ===============
# -- create_table(:active_admin_comments)
```

**Create admin user:**
```bash
# Rails console
rails console

# Create first admin user
AdminUser.create!(
  email: 'admin@example.com',
  password: 'password123',
  password_confirmation: 'password123'
)

# Exit
exit
```

**Configure ActiveAdmin:**
```bash
# Edit config/initializers/active_admin.rb
code config/initializers/active_admin.rb
```

**Update configuration:**
```ruby
# config/initializers/active_admin.rb
ActiveAdmin.setup do |config|
  config.site_title = "Chat API Admin"
  config.authentication_method = :authenticate_admin_user!
  config.current_user_method = :current_admin_user
  config.logout_link_path = :destroy_admin_user_session_path
  config.batch_actions = true
  config.filter_attributes = [:encrypted_password, :password, :password_confirmation]
  config.localize_format = :long
end
```

**Register models for admin:**
```bash
# Generate admin resources
rails generate active_admin:resource User
rails generate active_admin:resource Message
rails generate active_admin:resource Conversation

# These will be created later when models exist
# For now, we'll configure them in later phases
```

**Access ActiveAdmin:**
- Start Rails server (`rails s`)
- Visit: `http://localhost:3000/admin`
- Login with: `admin@example.com` / `password123`
- You'll see the admin dashboard

**Example Admin Resource (we'll add more later):**
```ruby
# app/admin/users.rb (create this later when User model exists)
ActiveAdmin.register User do
  permit_params :email, :username, :display_name, :bio

  index do
    selectable_column
    id_column
    column :username
    column :email
    column :display_name
    column :created_at
    actions
  end

  filter :email
  filter :username
  filter :created_at

  form do |f|
    f.inputs do
      f.input :username
      f.input :email
      f.input :display_name
      f.input :bio
    end
    f.actions
  end

  show do
    attributes_table do
      row :id
      row :username
      row :email
      row :display_name
      row :bio
      row :created_at
      row :updated_at
    end
  end
end
```

**Security Note:**
```ruby
# For production, add IP whitelist or additional authentication
# config/initializers/active_admin.rb

# Example: IP whitelist
# config.before_action do
#   unless ['127.0.0.1', 'your-office-ip'].include?(request.remote_ip)
#     redirect_to root_path, alert: 'Unauthorized'
#   end
# end
```

---

## Phase 7: Security & Monitoring

### Step 7.1: Setup rack-attack (Rate Limiting)

rack-attack protects API from spam, brute force attacks, and DDoS.

```bash
# Create rack-attack initializer
touch config/initializers/rack_attack.rb
code config/initializers/rack_attack.rb
```

**Add configuration:**
```ruby
# config/initializers/rack_attack.rb
class Rack::Attack
  # Throttle all requests by IP (60 requests per minute)
  throttle('req/ip', limit: 60, period: 1.minute) do |req|
    req.ip
  end

  # Throttle login attempts by email (5 attempts per 20 seconds)
  throttle('logins/email', limit: 5, period: 20.seconds) do |req|
    if req.path == '/api/v1/auth/login' && req.post?
      # Return the email if present, otherwise nil
      req.params['email']&.downcase
    end
  end

  # Throttle registration (3 attempts per 5 minutes per IP)
  throttle('registrations/ip', limit: 3, period: 5.minutes) do |req|
    if req.path == '/api/v1/auth/register' && req.post?
      req.ip
    end
  end

  # Throttle message creation (30 messages per minute per user)
  throttle('messages/user', limit: 30, period: 1.minute) do |req|
    if req.path.match?(/\/api\/v1\/conversations\/\d+\/messages/) && req.post?
      # Extract user ID from JWT token (implement this later)
      # For now, throttle by IP
      req.ip
    end
  end

  # Block requests from suspicious IPs (configure in production)
  blocklist('block suspicious IPs') do |req|
    # Example: Block specific IPs
    # ['1.2.3.4', '5.6.7.8'].include?(req.ip)
    false
  end

  # Allow localhost and private IPs in development
  safelist('allow localhost') do |req|
    # Requests from localhost or private IPs are always allowed
    req.ip == '127.0.0.1' ||
    req.ip == '::1' ||
    req.ip.start_with?('192.168.') ||
    req.ip.start_with?('10.')
  end

  # Custom response for throttled requests
  self.throttled_responder = lambda do |env|
    retry_after = env['rack.attack.match_data'][:period]
    [
      429,
      {
        'Content-Type' => 'application/json',
        'Retry-After' => retry_after.to_s
      },
      [{
        success: false,
        error: 'Too many requests. Please try again later.',
        retry_after: retry_after
      }.to_json]
    ]
  end

  # Custom response for blocked requests
  self.blocklisted_responder = lambda do |_env|
    [
      403,
      { 'Content-Type' => 'application/json' },
      [{ success: false, error: 'Forbidden' }.to_json]
    ]
  end
end

# Enable rack-attack
Rails.application.config.middleware.use Rack::Attack
```

**Configure Redis for rack-attack (recommended for production):**
```bash
# Edit config/initializers/rack_attack.rb (add to top)
code config/initializers/rack_attack.rb
```

**Add Redis cache store:**
```ruby
# config/initializers/rack_attack.rb (add to top)
Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(
  url: ENV.fetch('REDIS_URL') { 'redis://localhost:6379/1' }
)
```

**Test rack-attack:**
```bash
# Rails console
rails console

# Manually test throttle
# (In production, use actual requests)
# For now, just verify it loads
exit

# Test with curl (make 61 requests rapidly)
for i in {1..61}; do curl http://localhost:3000/api/v1/ping; done

# After 60 requests, you should see:
# {"success":false,"error":"Too many requests. Please try again later.","retry_after":60}
```

**Monitor rack-attack (optional - production):**
```ruby
# config/initializers/rack_attack.rb (add logging)
ActiveSupport::Notifications.subscribe('rack.attack') do |name, start, finish, request_id, payload|
  req = payload[:request]

  if [:throttle, :blocklist].include?(req.env['rack.attack.match_type'])
    Rails.logger.warn([
      'Rack::Attack',
      req.env['rack.attack.match_type'],
      req.ip,
      req.path,
      req.env['rack.attack.matched']
    ].join(' | '))
  end
end
```

### Step 7.2: Setup dotenv-rails (Environment Variables)

dotenv-rails is already installed, now ensure .env file loads properly.

**Verify .env file exists:**
```bash
# Check if .env exists
ls -la .env

# If not exists, create
touch .env
```

**Verify .env is in .gitignore:**
```bash
# Check .gitignore
grep "\.env" .gitignore

# If not found, add it
echo ".env" >> .gitignore
echo ".env.local" >> .gitignore
echo ".env.*.local" >> .gitignore
```

**Update .env file with all variables:**
```bash
code .env
```

**Complete .env template:**
```bash
# Database (optional for development - uses Unix socket by default)
# Uncomment only if using TCP connection or custom PostgreSQL user:
# POSTGRES_USER=your_username
# POSTGRES_PASSWORD=your_password

# Redis
REDIS_URL=redis://localhost:6379/0

# JWT Secret (REQUIRED - generate with: rails secret)
JWT_SECRET_KEY=your_super_secret_key_here_generate_with_rake_secret

# Rails
RAILS_ENV=development
RAILS_MAX_THREADS=5

# Sidekiq
SIDEKIQ_CONCURRENCY=2

# rack-attack
RACK_ATTACK_ENABLED=true
RATE_LIMIT_REQUESTS_PER_MINUTE=60

# Application settings
APP_NAME=ChatAPI
APP_VERSION=1.0.0
```

**Generate new secret:**
```bash
# Generate secret for JWT
rails secret

# Copy output and paste to .env as JWT_SECRET_KEY
```

**Test dotenv loading:**
```bash
# Rails console
rails console

# Check if env variables loaded
ENV['JWT_SECRET_KEY']
# Should return your secret key

ENV['REDIS_URL']
# Should return redis://localhost:6379/0

exit
```

**Note:** dotenv-rails automatically loads .env in development and test environments. No configuration needed!

### Step 7.3: Setup lograge (Structured Logging)

Lograge converts verbose Rails logs into single-line structured logs.

**Configure lograge:**
```bash
# Create lograge initializer
touch config/initializers/lograge.rb
code config/initializers/lograge.rb
```

**Add configuration:**
```ruby
# config/initializers/lograge.rb
Rails.application.configure do
  # Enable lograge
  config.lograge.enabled = true

  # Use JSON format (easier to parse)
  config.lograge.formatter = Lograge::Formatters::Json.new

  # Add custom fields to log
  config.lograge.custom_options = lambda do |event|
    {
      time: Time.current,
      host: event.payload[:host],
      remote_ip: event.payload[:remote_ip],
      user_id: event.payload[:user_id],
      request_id: event.payload[:request_id],
      exception: event.payload[:exception]&.first,
      exception_message: event.payload[:exception]&.last
    }
  end

  # Log query parameters (be careful with sensitive data!)
  config.lograge.custom_payload do |controller|
    {
      host: controller.request.host,
      remote_ip: controller.request.remote_ip,
      user_id: controller.try(:current_user)&.id,
      request_id: controller.request.uuid
    }
  end

  # Keep SQL logs separate (optional)
  config.lograge.keep_original_rails_log = false

  # Ignore healthcheck endpoint
  config.lograge.ignore_actions = ['Rails::HealthController#show']
end
```

**Configure log level (optional):**
```bash
# Edit config/environments/development.rb
code config/environments/development.rb
```

**Add/modify log level:**
```ruby
# config/environments/development.rb
Rails.application.configure do
  # ...existing config...

  # Log level
  config.log_level = :debug  # :debug, :info, :warn, :error, :fatal

  # Log to STDOUT (good for Docker)
  config.logger = ActiveSupport::Logger.new($stdout)

  # ...rest of config...
end
```

**Test lograge:**
```bash
# Start Rails server
rails s

# In another terminal, make a request
curl http://localhost:3000/api/v1/ping

# Check logs (should be single-line JSON)
tail -f log/development.log
```

**Expected log output (before lograge):**
```
Started GET "/api/v1/ping" for 127.0.0.1 at 2025-12-25 12:00:00
Processing by Api::V1::PingController#index as */*
  Parameters: {}
Completed 200 OK in 5ms (Views: 0.5ms | ActiveRecord: 0.0ms)
```

**Expected log output (after lograge):**
```json
{"method":"GET","path":"/api/v1/ping","format":"*/*","controller":"Api::V1::PingController","action":"index","status":200,"duration":5.23,"view":0.45,"db":0.0,"time":"2025-12-25T12:00:00Z","host":"localhost","remote_ip":"127.0.0.1","request_id":"abc-123"}
```

**Production logging configuration:**
```ruby
# config/environments/production.rb
Rails.application.configure do
  # Log to STDOUT (for Heroku, Docker, Kubernetes)
  config.logger = ActiveSupport::Logger.new($stdout)

  # Log level
  config.log_level = :info

  # Log tags (helpful for debugging)
  config.log_tags = [:request_id]

  # Lograge settings
  config.lograge.enabled = true
  config.lograge.formatter = Lograge::Formatters::Json.new
end
```

**Lograge with external services (optional - production):**
```ruby
# For Datadog, New Relic, or other APM tools
# Add to config/initializers/lograge.rb

# Example: Log to external service
config.lograge.logger = ActiveSupport::Logger.new("#{Rails.root}/log/lograge.log")

# Or send to stdout for Docker/Kubernetes
config.lograge.logger = ActiveSupport::Logger.new($stdout)
```

---

## Phase 8: Error Handling & Observability

Industry-standard error handling with proper 4xx/5xx separation, structured error responses, and production error tracking.

### Why Proper Error Handling Matters

**Observability Goals:**
- 4xx errors (client mistakes) → Don't trigger alerts
- 5xx errors (server issues) → Trigger alerts immediately
- Simple Grafana query: `http_status=~"5.."` to monitor application health
- Structured error responses for API consumers

### Step 8.1: Understand the Error Handling Strategy

**The base_controller already implements comprehensive error handling** (configured in Step 6.1).

**Error Categories:**

| Status | Type | Description | Log Level | Alert? |
|--------|------|-------------|-----------|--------|
| 400 | `bad_request` | Missing/invalid parameters | info | No |
| 401 | `unauthorized` | Not authenticated | info | No |
| 403 | `forbidden` | Not authorized (Pundit) | info | No |
| 404 | `not_found` | Resource doesn't exist | info | No |
| 409 | `conflict` | Duplicate resource | info | No |
| 422 | `validation_error` | Validation failed | info | No |
| 429 | `rate_limit_exceeded` | Too many requests | warn | No |
| 500 | `internal_error` | Unexpected exception | error | **Yes** |
| 503 | `service_unavailable` | Service down | error | **Yes** |

**Error Response Format:**

All errors return consistent JSON:

```json
{
  "error": {
    "type": "validation_error",
    "message": "Validation failed",
    "details": {
      "email": ["can't be blank", "is invalid"],
      "password": ["is too short (minimum is 8 characters)"]
    },
    "request_id": "abc-123-def-456",
    "timestamp": "2026-01-01T12:00:00Z"
  }
}
```

**Environment-Aware Security:**

| Environment | 4xx Errors | 5xx Errors |
|-------------|------------|------------|
| Development | Full details + validation errors | Full details + stack trace |
| Production | Full details + validation errors | Generic message only (security) |

**Example - Development 500 error:**
```json
{
  "error": {
    "type": "internal_error",
    "message": "NoMethodError: undefined method `name' for nil",
    "details": {
      "exception": "NoMethodError",
      "backtrace": ["app/controllers/...", "..."]
    },
    "request_id": "abc-123"
  }
}
```

**Example - Production 500 error:**
```json
{
  "error": {
    "type": "internal_error",
    "message": "An unexpected error occurred. Please contact support with request_id: abc-123",
    "request_id": "abc-123",
    "timestamp": "2026-01-01T12:00:00Z"
  }
}
```

### Step 8.2: Setup Sentry (Error Tracking)

Sentry automatically captures 5xx errors with full context for investigation.

**Install Sentry gems:**
```bash
# Already added to Gemfile
# gem "sentry-ruby"
# gem "sentry-rails"

# Install gems
bundle install
```

**Configure Sentry:**

The initializer is already created at `config/initializers/sentry.rb`.

**Get Sentry DSN:**

1. Create free account: https://sentry.io/signup/
2. Create new project → Select "Rails"
3. Copy your DSN (looks like: `https://abc123@o123.ingest.sentry.io/456`)

**Add to .env:**
```bash
# Edit .env
code .env
```

**Add Sentry configuration:**
```bash
# ============================================
# Error Tracking (Sentry)
# ============================================
# Get your DSN from: https://sentry.io/settings/[org]/projects/[project]/keys/
# Only needed for production/staging (development errors are logged locally)
SENTRY_DSN=https://your-sentry-dsn-here
SENTRY_TRACES_SAMPLE_RATE=0.1  # Performance monitoring: 0.1 = 10%
```

**For development, you can skip Sentry** - it only runs in production/staging (configured in initializer).

### Step 8.3: Test Error Handling

**Test validation error (422):**
```bash
# Start Rails server
rails s

# Test validation error (will be implemented when models exist)
# For now, test with ping controller
```

**Test not found error (404):**
```bash
# Trigger 404 error
curl http://localhost:3000/api/v1/users/99999

# Expected response:
{
  "error": {
    "type": "not_found",
    "message": "Couldn't find User with 'id'=99999",
    "request_id": "abc-123",
    "timestamp": "2026-01-01T12:00:00Z"
  }
}
```

**Test internal error (500):**

Create a test endpoint that raises an error:

```ruby
# app/controllers/api/v1/ping_controller.rb
def index
  # Uncomment to test 500 error
  # raise StandardError, "Test error for Sentry"

  render_success({
    message: 'pong',
    timestamp: Time.current,
    version: 'v1'
  })
end
```

```bash
# Trigger 500 error
curl http://localhost:3000/api/v1/ping

# Expected response (development):
{
  "error": {
    "type": "internal_error",
    "message": "StandardError: Test error for Sentry",
    "details": {
      "exception": "StandardError",
      "backtrace": ["..."]
    },
    "request_id": "abc-123"
  }
}

# Check logs - should see:
# [INTERNAL ERROR] StandardError: Test error for Sentry | Request ID: abc-123 ...
```

### Step 8.4: Grafana Alert Configuration (Production)

With this error handling, you can set up simple Grafana alerts:

**Alert on 5xx errors only:**
```promql
# Prometheus/Grafana query
rate(http_requests_total{status=~"5.."}[5m]) > 0

# Alert when ANY 5xx error occurs in last 5 minutes
```

**Why this works:**
- 4xx errors (client mistakes) are logged as `info` → Don't trigger alerts
- 5xx errors (server issues) are logged as `error` → Trigger alerts
- Clean separation, no false alarms

**Log-based alert (alternative):**
```
# Alert on error logs containing "[INTERNAL ERROR]"
source="rails" "[INTERNAL ERROR]"
```

### Step 8.5: Error Handling Best Practices

**DO:**
- ✅ Always include `request_id` in error responses (for support)
- ✅ Use structured error types (`validation_error`, not just message)
- ✅ Show detailed validation errors for 4xx (helps API consumers)
- ✅ Hide internal details for 5xx in production (security)
- ✅ Log 4xx as info, 5xx as error (proper alerting)
- ✅ Send 5xx errors to Sentry (for investigation)

**DON'T:**
- ❌ Don't return stack traces in production (security risk)
- ❌ Don't alert on 4xx errors (false alarms)
- ❌ Don't use generic error messages (hard to debug)
- ❌ Don't skip `request_id` (makes support impossible)
- ❌ Don't log sensitive data (passwords, tokens, credit cards)

### Step 8.6: Using Error Handling in Controllers

**The base_controller handles most errors automatically.** You rarely need to manually render errors.

**Automatic handling examples:**

```ruby
# app/controllers/api/v1/users_controller.rb
class Api::V1::UsersController < BaseController
  def show
    # Automatically returns 404 if not found
    user = User.find(params[:id])
    render_success(UserBlueprint.render_as_hash(user))
  end

  def create
    # Automatically returns 422 if validation fails
    user = User.create!(user_params)
    render_success(UserBlueprint.render_as_hash(user), status: :created)
  end

  def update
    user = User.find(params[:id])
    # Automatically returns 422 if validation fails
    user.update!(user_params)
    render_success(UserBlueprint.render_as_hash(user))
  end

  private

  def user_params
    # Automatically returns 400 if required params missing
    params.require(:user).permit(:email, :username, :display_name)
  end
end
```

**Manual error handling (rare):**

```ruby
# Only use when you need custom error handling
def custom_action
  if some_business_logic_fails
    render_error(
      type: 'business_logic_error',
      message: 'Cannot perform action because...',
      status: :unprocessable_entity
    )
    return
  end

  # Success case
  render_success(data)
end
```

### Step 8.7: Adding Custom Error Handlers

**When you add authentication (JWT):**

Uncomment in `app/controllers/api/v1/base_controller.rb`:

```ruby
# Add to rescue_from declarations
rescue_from JWT::DecodeError, with: :handle_unauthorized
rescue_from JWT::ExpiredSignature, with: :handle_unauthorized
```

**When you add authorization (Pundit):**

Uncomment in `app/controllers/api/v1/base_controller.rb`:

```ruby
# Add to rescue_from declarations
rescue_from Pundit::NotAuthorizedError, with: :handle_forbidden
```

**When you add rate limiting:**

Update `config/initializers/rack_attack.rb` to return proper error format:

```ruby
# Already configured - returns:
{
  "error": {
    "type": "rate_limit_exceeded",
    "message": "Too many requests. Please try again later.",
    "retry_after": 60,
    "request_id": "abc-123"
  }
}
```

### Step 8.8: Monitoring in Production

**What to monitor:**

1. **Error rate:** Count of 5xx responses
2. **Error types:** Group by `error.type`
3. **Request IDs:** Track specific user issues
4. **Performance:** Response times (Sentry captures this)

**Sentry Dashboard shows:**
- Error frequency graph
- Affected user count
- Stack traces with context
- Breadcrumbs (user actions leading to error)
- Release versions (which deploy caused the error)

**Example Sentry alert:**
```
Alert: 5xx Error Rate > 1%
Project: chat-api
Error: NoMethodError in UsersController#show
Affected users: 15
First seen: 2 minutes ago
```

---

## Testing Your Setup

### Test 1: Start Rails Server

```bash
# Start Rails server
rails server

# or
rails s

# Expected output:
# => Booting Puma
# => Rails 8.1.1 application starting in development
# => Run `bin/rails server --help` for more startup options
# Puma starting in single mode...
# * Listening on http://127.0.0.1:3000

# Server running at http://localhost:3000
```

### Test 2: Test Endpoints

**Open new terminal tab, test with curl:**

```bash
# Test health check
curl http://localhost:3000/up

# Expected: status 200 OK

# Test ping endpoint
curl http://localhost:3000/api/v1/ping

# Expected output:
# {"success":true,"data":{"message":"pong","timestamp":"2025-12-25T...","version":"v1"}}
```

**Or open in browser:**
```
http://localhost:3000/api/v1/ping
```

### Test 3: Check Redis Connection

```bash
# Rails console
rails console

# or
rails c

# Test Redis
irb> $redis.ping
# => "PONG"

irb> $redis.set('test', 'Hello from Rails!')
# => "OK"

irb> $redis.get('test')
# => "Hello from Rails!"

irb> exit
```

### Test 4: Run Tests

```bash
# Run RSpec
bundle exec rspec

# Run Rubocop
bundle exec rubocop

# Run Brakeman (security check)
bundle exec brakeman

# Run Bundler Audit
bundle exec bundler-audit check --update
```

### Test 5: Start Sidekiq

**Open new terminal tab:**

```bash
cd /Users/irvan/Projects/chat-api

# Start Sidekiq
bundle exec sidekiq

# Expected output:
# Booting Sidekiq...
# Starting processing...
```

---

## Development Workflow Commands

### Daily Commands

```bash
# Start Rails server
rails s

# Start Rails console
rails c

# Start Sidekiq (in separate terminal)
bundle exec sidekiq

# Run tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/models/user_spec.rb

# Check code quality
bundle exec rubocop
bundle exec rubocop -A  # Auto-fix

# Database commands
rails db:migrate              # Run pending migrations
rails db:rollback            # Rollback last migration
rails db:seed                # Seed database
rails db:reset               # Drop, create, migrate, seed
rails db:migrate:status      # Check migration status

# Generate commands
rails g model User email:string username:string
rails g controller Api::V1::Users
rails g migration AddFieldToTable field:type

# Routes
rails routes                 # Show all routes
rails routes | grep user     # Filter routes
```

### Useful Commands

```bash
# Check Rails version
rails -v

# Check Ruby version
ruby -v

# Check gem versions
bundle list

# Update gems
bundle update

# Clear cache
rails tmp:clear

# Database console
rails dbconsole
# or
psql chat_api_development

# Check logs
tail -f log/development.log

# Asset precompile (if needed)
rails assets:precompile
```

---

## Troubleshooting

### Issue: Can't connect to PostgreSQL

**Solution:**
```bash
# Check if PostgreSQL is running
brew services list | grep postgresql

# If not running, start it
brew services start postgresql@17

# Check connection
psql chat_api_development
```

### Issue: Can't connect to Redis

**Solution:**
```bash
# Check if Redis is running
brew services list | grep redis

# If not running, start it
brew services start redis

# Test connection
redis-cli ping
```

### Issue: Bundle install fails

**Solution:**
```bash
# Update bundler
gem install bundler

# Clear cache and reinstall
rm Gemfile.lock
bundle install
```

### Issue: Port 3000 already in use

**Solution:**
```bash
# Find process using port 3000
lsof -i :3000

# Kill the process
kill -9 <PID>

# Or run on different port
rails s -p 3001
```

---

## Next Steps

After setup is complete, you can proceed to:

1. **Create Database Migrations** for core models (users, conversations, messages, etc.)
2. **Setup Authentication** (JWT)
3. **Implement API Endpoints**
4. **Setup ActionCable** for real-time features

See **[Project Overview](../architecture/overview.md)** for detailed implementation plan.

---

## Git Setup (Optional)

```bash
# Initialize git
git init

# Create .gitignore (should already exist)
cat >> .gitignore << EOF
# Environment variables
.env
.env.local

# Database
*.sqlite3

# Logs
log/*
tmp/*

# IDE
.idea/
.vscode/
*.swp
*.swo

# OS
.DS_Store
EOF

# Initial commit
git add .
git commit -m "Initial commit: Rails 8.1.1 API setup with PostgreSQL, Redis, Sidekiq"

# Add remote (if you have GitHub repo)
# git remote add origin https://github.com/yourusername/chat-api.git
# git push -u origin main
```

---

## Environment Variables Reference

**Development (.env):**
```bash
# Database (optional - uses Unix socket by default)
# POSTGRES_USER=your_username
# POSTGRES_PASSWORD=your_password

# Redis
REDIS_URL=redis://localhost:6379/0

# JWT (REQUIRED)
JWT_SECRET_KEY=your_secret_key_from_rails_secret

# Rails
RAILS_ENV=development
RAILS_MAX_THREADS=5

# Sidekiq
SIDEKIQ_CONCURRENCY=2

# rack-attack
RACK_ATTACK_ENABLED=true
RATE_LIMIT_REQUESTS_PER_MINUTE=60
```

**Production (set in your hosting platform):**
```bash
# Database
POSTGRES_USER=chat_api
POSTGRES_PASSWORD=your_production_password
POSTGRES_HOST=your-db-host.com
POSTGRES_PORT=5432

# Or use single DATABASE_URL (alternative)
# DATABASE_URL=postgresql://user:password@host:5432/dbname

# Redis
REDIS_URL=redis://your-redis-host:6379/0

# JWT
JWT_SECRET_KEY=your_production_secret

# Rails
RAILS_ENV=production
RAILS_MAX_THREADS=10
RAILS_SERVE_STATIC_FILES=true
RAILS_LOG_TO_STDOUT=true

# Sidekiq
SIDEKIQ_CONCURRENCY=10

# rack-attack
RACK_ATTACK_ENABLED=true
RATE_LIMIT_REQUESTS_PER_MINUTE=120
```

---

## Resources

- Rails Guides: https://guides.rubyonrails.org/
- Rails API Docs: https://api.rubyonrails.org/
- PostgreSQL Docs: https://www.postgresql.org/docs/
- Redis Docs: https://redis.io/docs/
- Sidekiq Wiki: https://github.com/sidekiq/sidekiq/wiki
- RSpec Rails: https://github.com/rspec/rspec-rails
- Rubocop: https://docs.rubocop.org/

---

**Happy Coding! 🚀**
