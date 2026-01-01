# config/initializers/cors_validator.rb
Rails.application.config.after_initialize do
  # Skip validation in test environment
  next if Rails.env.test?

  cors_origins = ENV.fetch('CORS_ORIGINS', '')

  # Validate in production
  if Rails.env.production?
    if cors_origins.blank?
      Rails.logger.error "CORS ERROR: CORS_ORIGINS is not configured for production!"
      raise "CORS_ORIGINS environment variable is required in production"
    end

    if cors_origins.include?('*')
      Rails.logger.error "CORS ERROR: Wildcard (*) is not allowed in production!"
      raise "CORS_ORIGINS cannot use wildcard (*) in production"
    end

    if cors_origins.include?('localhost')
      Rails.logger.warn "CORS WARNING: localhost detected in production CORS_ORIGINS"
    end

    Rails.logger.info "CORS: Configured for #{cors_origins.split(',').count} origin(s)"
  end

  # Info in development
  if Rails.env.development?
    if cors_origins.blank?
      Rails.logger.info "CORS: Using wildcard (*) for development (CORS_ORIGINS not set)"
    else
      Rails.logger.info "CORS: Configured for #{cors_origins.split(',').count} origin(s)"
    end
  end
end
