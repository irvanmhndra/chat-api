# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin Ajax requests.

# Read more: https://github.com/cyu/rack-cors

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
