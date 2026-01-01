# Sentry Error Tracking Configuration
# https://docs.sentry.io/platforms/ruby/guides/rails/

Sentry.init do |config|
  # Sentry DSN (Data Source Name) - unique identifier for your project
  # Get this from: https://sentry.io/settings/[org]/projects/[project]/keys/
  config.dsn = ENV['SENTRY_DSN']

  # Only enable Sentry if DSN is configured (production/staging)
  config.enabled_environments = %w[production staging]

  # Set current environment
  config.environment = Rails.env

  # Set release version (for tracking which version had the error)
  # Option 1: Use git commit SHA
  # config.release = ENV.fetch('GIT_COMMIT_SHA', 'unknown')

  # Option 2: Use app version from environment
  # config.release = ENV.fetch('APP_VERSION', 'unknown')

  # Option 3: Let Sentry auto-detect from git
  # (Comment out to use auto-detection)

  # Breadcrumbs configuration (tracks user actions leading to error)
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]

  # Sample rate for performance monitoring (0.0 to 1.0)
  # 0.1 = 10% of transactions, 1.0 = 100%
  # Start low to avoid overwhelming Sentry in high-traffic apps
  config.traces_sample_rate = ENV.fetch('SENTRY_TRACES_SAMPLE_RATE', 0.1).to_f

  # Profiling sample rate (captures performance profiles)
  # Only works if traces_sample_rate > 0
  # config.profiles_sample_rate = 0.1

  # Filter sensitive data from error reports
  config.before_send = lambda do |event, hint|
    # Remove sensitive parameters
    if event.request
      event.request.data&.delete('password')
      event.request.data&.delete('password_confirmation')
      event.request.data&.delete('credit_card')
      event.request.data&.delete('ssn')
    end

    # Don't send test errors to Sentry
    return nil if Rails.env.test?

    event
  end

  # Configure which exceptions to ignore (don't send to Sentry)
  # These are common exceptions that aren't actionable
  config.excluded_exceptions += [
    'ActionController::RoutingError',
    'ActiveRecord::RecordNotFound',
    'ActionController::InvalidAuthenticityToken',
    'ActionController::UnknownFormat',
    'Rack::Timeout::RequestTimeoutException'
  ]

  # Send additional context with errors
  config.before_send_transaction = lambda do |event, hint|
    # Add custom tags for filtering/grouping
    event.set_tag('server_name', ENV['HOSTNAME']) if ENV['HOSTNAME']

    event
  end
end

# =============================================================================
# USAGE EXAMPLES
# =============================================================================

# 1. Automatic capture (already handled by base_controller.rb):
#    - All unhandled exceptions are automatically sent to Sentry
#
# 2. Manual capture (for specific scenarios):
#    begin
#      risky_operation
#    rescue => e
#      Sentry.capture_exception(e)
#      # Handle error...
#    end
#
# 3. Capture custom messages:
#    Sentry.capture_message("Something went wrong", level: :warning)
#
# 4. Add context to current scope:
#    Sentry.set_user(id: current_user.id, email: current_user.email)
#    Sentry.set_tags(feature: 'checkout', payment_method: 'stripe')
#    Sentry.set_context('order', { id: order.id, total: order.total })

# =============================================================================
# GETTING STARTED
# =============================================================================
#
# 1. Create free account: https://sentry.io/signup/
# 2. Create new project (select Rails)
# 3. Copy DSN from project settings
# 4. Add to .env:
#    SENTRY_DSN=https://abc123@o123.ingest.sentry.io/456
# 5. Deploy and errors will automatically be tracked!
#
# Optional environment variables:
# - SENTRY_TRACES_SAMPLE_RATE=0.1  (performance monitoring sample rate)
# - GIT_COMMIT_SHA=abc123           (for release tracking)
