source "https://rubygems.org"

ruby "3.4.8"

# Core
gem "rails", "~> 8.1.1"
gem 'pg', '~> 1.6', '>= 1.6.2'
gem 'puma', '~> 7.1'

# Authentication & Authorization
gem "jwt"
gem 'bcrypt', '~> 3.1', '>= 3.1.20'
gem "pundit"

# Redis & Background Jobs
gem 'redis', '~> 5.4', '>= 5.4.1'
gem "sidekiq"

# File Upload (add later after setting up Active Storage)
# gem "image_processing", "~> 1.2"

# API & Serialization
gem "blueprinter"  # Modern JSON serializer (7-10x faster than Jbuilder)
gem "oj"           # Fast JSON parser
gem "rack-cors"
gem "pagy"

# API Documentation
gem 'rswag-api'    # Serves OpenAPI/Swagger JSON spec
gem 'rswag-ui'     # Swagger UI for interactive API docs

# Security & Rate Limiting
gem "rack-attack"  # Rate limiting & throttling (prevent spam, brute force, DDoS)

# Environment & Configuration
gem "dotenv-rails"  # Load environment variables from .env file

# Logging & Error Tracking
gem "lograge"         # Clean, structured logging (single-line logs)
gem "sentry-ruby"     # Error tracking & monitoring
gem "sentry-rails"    # Rails integration for Sentry

# Feature Flags (Trunk-Based Development)
gem "flipper"
gem "flipper-active_record"  # Store flags in PostgreSQL
gem "flipper-ui"             # Web UI for managing flags

# Admin Panel
gem "activeadmin"            # Admin dashboard
gem "devise"                 # Authentication (required by ActiveAdmin)
gem "sassc-rails"           # Sass compiler for ActiveAdmin styles

# Speeds up boot times
gem "bootsnap", require: false

# Windows timezone data
gem "tzinfo-data", platforms: %i[ windows jruby ]

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem 'rspec-rails', '~> 8.0', '>= 8.0.2'
  gem "factory_bot_rails"
  gem "faker"
  gem "pry-rails"
  gem "bullet"  # N+1 detection
  gem 'rswag-specs'  # RSpec integration for API documentation

  # Code Quality & Linting
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
  gem "rubocop-rspec", require: false
  gem "rubocop-performance", require: false
  gem "brakeman"
end

group :development do
  gem "annotate"
  gem "bundler-audit"
end

group :test do
  gem "shoulda-matchers"
  gem "simplecov", require: false
  gem "database_cleaner-active_record"
end