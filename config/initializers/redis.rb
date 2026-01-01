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