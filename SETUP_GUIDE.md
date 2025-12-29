# Chat API - Setup Guide 🚀

Panduan lengkap untuk setup project Chat API dari nol. Ikuti step-by-step agar Anda memahami setiap langkah.

---

## Prerequisites - Install Dependencies

### 1. Install Ruby 3.3+

**macOS (menggunakan rbenv - recommended):**
```bash
# Install rbenv
brew install rbenv ruby-build

# Install Ruby 3.3.0 (atau latest 3.3.x)
rbenv install 3.3.0

# Set sebagai default
rbenv global 3.3.0

# Verify
ruby -v
# Output: ruby 3.3.0 (atau yang lebih baru)
```

**Alternative menggunakan asdf:**
```bash
# Install asdf
brew install asdf

# Add ruby plugin
asdf plugin add ruby

# Install Ruby
asdf install ruby 3.3.0
asdf global ruby 3.3.0

# Verify
ruby -v
```

### 2. Install PostgreSQL

**macOS:**
```bash
# Option 1: Install latest stable (PostgreSQL 17 - recommended)
brew install postgresql@17
brew services start postgresql@17

# Option 2: Install bleeding edge (PostgreSQL 18 - latest)
brew install postgresql@18
brew services start postgresql@18

# Option 3: Install latest version (auto-selects newest)
brew install postgresql
brew services start postgresql

# Verify
psql --version
# Output: psql (PostgreSQL) 17.x or 18.x
```

**Which version to choose?**
- **PostgreSQL 18**: Latest features, bleeding edge (baru released/beta)
- **PostgreSQL 17**: Stable, battle-tested, production-ready ✅ (Recommended)
- **PostgreSQL 16**: Very stable, widely used in production

**Note:** Untuk development, bisa pakai version terbaru. Untuk production, PostgreSQL 17 lebih recommended karena sudah lebih mature.

```bash
# Check installed version
psql --version

# If you have old version (< 16), consider upgrade:
brew upgrade postgresql
```

**Default PostgreSQL Configuration (macOS/Linux):**

Rails 8.1 menggunakan **Unix domain socket** secara default untuk koneksi database di development. Ini berarti:
- ✅ **No username/password needed** untuk development
- ✅ Koneksi otomatis pakai system user (contoh: user `irvan` di macOS)
- ✅ Lebih cepat dari TCP connection
- ✅ Lebih aman (no network exposure)

**Tidak perlu create PostgreSQL user khusus!** Rails akan otomatis connect dengan user system Anda.

Jika ingin pakai TCP connection atau custom user (optional):
```bash
# Login ke psql
psql postgres

# Create user (di psql prompt)
CREATE USER chat_api_user WITH PASSWORD 'your_password' CREATEDB;

# Exit
\q

# Then uncomment host/username/password di database.yml
```

### 3. Install Redis

**macOS:**
```bash
# Install Redis
brew install redis

# Start Redis service
brew services start redis

# Verify
redis-cli ping
# Output: PONG
```

**Test Redis:**
```bash
# Connect to Redis
redis-cli

# Try some commands
127.0.0.1:6379> SET test "Hello"
127.0.0.1:6379> GET test
# Output: "Hello"
127.0.0.1:6379> exit
```

### 4. Install Rails 8.1.1

```bash
# Install Rails
gem install rails -v 8.1.1

# Verify
rails -v
# Output: Rails 8.1.1
```

### 5. Install Node.js (untuk Asset Pipeline jika diperlukan)

```bash
# Install Node.js
brew install node

# Verify
node -v
npm -v
```

### 6. Install ImageMagick (untuk image processing)

```bash
# Install ImageMagick
brew install imagemagick

# Verify
magick -version
```

---

## Phase 1: Create Rails Project

### Step 1.1: Generate Rails API Project

```bash
# Navigate ke directory Projects
cd /Users/irvan/Projects

# Create new Rails API project dengan PostgreSQL
rails new chat-api \
  --api \
  --database=postgresql \
  --skip-action-mailer \
  --skip-action-mailbox \
  --skip-action-text \
  --skip-active-storage \
  --skip-action-cable \
  --skip-jbuilder \
  -T

# Penjelasan flags:
# --api                : API-only mode (no views, helpers, assets)
# --database=postgresql: Use PostgreSQL
# --skip-action-mailer : Skip mailer (kita add manual nanti)
# --skip-active-storage: Skip active storage (kita add manual nanti)
# --skip-action-cable  : Skip action cable (kita add manual nanti)
# --skip-jbuilder      : Skip jbuilder (kita pakai Blueprint!)
# -T                   : Skip minitest (kita pakai RSpec)

# Navigate ke project directory
cd chat-api
```

### Step 1.2: Update Gemfile (IMPORTANT - Do This First!)

**⚠️ PENTING:** Update Gemfile SEBELUM configure database atau run Rails commands!

```bash
# Open Gemfile
code Gemfile
```

**Replace dengan:**
```ruby
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

# Security & Rate Limiting
gem "rack-attack"  # Rate limiting & throttling (prevent spam, brute force, DDoS)

# Environment & Configuration
gem "dotenv-rails"  # Load environment variables from .env file

# Logging
gem "lograge"  # Clean, structured logging (single-line logs)

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
```

### Step 1.3: Install All Gems

```bash
# Install all gems (IMPORTANT!)
bundle install

# This might take a few minutes...
# Expected output: Bundle complete! XX Gemfile dependencies, YY gems now installed.
```

**⚠️ Kenapa bundle install di sini?**
- Rails new sudah auto bundle install (default gems)
- Kita baru update Gemfile dengan gems tambahan
- **HARUS** bundle install lagi sebelum run Rails commands!
- Gems seperti `jwt`, `pundit`, `blueprinter` dibutuhkan

### Step 1.4: Verify Installation

```bash
# Check installed gems
bundle list | grep rspec
# Should show: rspec-rails

bundle list | grep blueprinter
# Should show: blueprinter

bundle list | grep jwt
# Should show: jwt
```

### Step 1.5: Configure Database

```bash
# Edit config/database.yml
# Buka dengan editor favorit (vim, nano, vscode, dll)
code config/database.yml  # or vim, nano, etc.
```

**Update config/database.yml:**
```yaml
default: &default
  adapter: postgresql
  encoding: unicode
  # Rails 8.1+ uses max_connections (renamed from 'pool')
  max_connections: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>

development:
  <<: *default
  database: chat_api_development
  # Uses Unix socket by default (no host/username/password needed on macOS/Linux)
  # Uncomment below only if you need TCP connection or custom PostgreSQL user:
  # host: localhost
  # username: <%= ENV.fetch("POSTGRES_USER", ENV["USER"]) %>
  # password: <%= ENV["POSTGRES_PASSWORD"] %>

test:
  <<: *default
  database: chat_api_test

production:
  <<: *default
  database: chat_api_production
  username: <%= ENV["POSTGRES_USER"] %>
  password: <%= ENV["POSTGRES_PASSWORD"] %>
  host: <%= ENV.fetch("POSTGRES_HOST", "localhost") %>
  port: <%= ENV.fetch("POSTGRES_PORT", 5432) %>
```

**Create .env file untuk development:**
```bash
# Create .env file
touch .env

# Add to .gitignore
echo ".env" >> .gitignore
```

**Edit .env:**
```bash
# Database (optional for development - uses Unix socket by default)
# Uncomment only if using TCP connection or custom PostgreSQL user:
# POSTGRES_USER=your_username
# POSTGRES_PASSWORD=your_password

# Redis
REDIS_URL=redis://localhost:6379/0

# JWT Secret
JWT_SECRET_KEY=your_super_secret_key_here_generate_with_rake_secret

# Rails
RAILS_MAX_THREADS=5
```

**Generate secret key:**
```bash
# Generate secret key untuk JWT
rails secret

# Copy output dan paste ke .env sebagai JWT_SECRET_KEY
```

### Step 1.6: Create Database

**NOW** we can safely run Rails commands karena gems sudah terinstall!

```bash
# Create databases
rails db:create

# Expected output:
# Created database 'chat_api_development'
# Created database 'chat_api_test'

# Verify
rails db:migrate:status
```

---

## Phase 2: Setup RSpec & Code Quality Tools

### Step 2.1: Setup RSpec

```bash
# Generate RSpec configuration
rails generate rspec:install

# Expected output:
#   create  .rspec
#   create  spec
#   create  spec/spec_helper.rb
#   create  spec/rails_helper.rb

# Run RSpec to verify
bundle exec rspec

# Expected: 0 examples, 0 failures
```

### Step 2.2: Configure RSpec

**Edit spec/rails_helper.rb:**
```bash
code spec/rails_helper.rb
```

**Add at the bottom (before `RSpec.configure`):**
```ruby
# Shoulda Matchers configuration
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end

# Database Cleaner configuration
RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end
end
```

### Step 2.3: Setup Rswag (API Documentation)

Rswag generates interactive Swagger/OpenAPI documentation from RSpec tests.

```bash
# Install Rswag
rails generate rswag:install

# This creates:
# - config/initializers/rswag_api.rb
# - config/initializers/rswag_ui.rb
# - spec/swagger_helper.rb
# - swagger/v1/swagger.yaml
```

**Configure Rswag:**
```bash
# Edit spec/swagger_helper.rb
code spec/swagger_helper.rb
```

**Update configuration:**
```ruby
# spec/swagger_helper.rb
require 'rails_helper'

RSpec.configure do |config|
  config.swagger_root = Rails.root.join('swagger').to_s

  config.swagger_docs = {
    'v1/swagger.yaml' => {
      openapi: '3.0.1',
      info: {
        title: 'Chat API',
        version: 'v1',
        description: 'Real-time chat messaging API with WebSocket support'
      },
      paths: {},
      servers: [
        {
          url: 'http://localhost:3000',
          variables: {
            defaultHost: {
              default: 'localhost:3000'
            }
          }
        }
      ],
      components: {
        securitySchemes: {
          Bearer: {
            type: :http,
            scheme: :bearer,
            bearerFormat: 'JWT',
            description: 'JWT token for authentication'
          }
        }
      }
    }
  }

  config.swagger_format = :yaml
end
```

**Create example API spec:**
```bash
# Create integration test directory
mkdir -p spec/integration/api/v1

# Create ping endpoint spec
touch spec/integration/api/v1/ping_spec.rb
code spec/integration/api/v1/ping_spec.rb
```

**Add example spec:**
```ruby
# spec/integration/api/v1/ping_spec.rb
require 'swagger_helper'

describe 'Ping API' do
  path '/api/v1/ping' do
    get 'Health check endpoint' do
      tags 'Health'
      produces 'application/json'

      response '200', 'successful' do
        schema type: :object,
          properties: {
            success: { type: :boolean },
            data: {
              type: :object,
              properties: {
                message: { type: :string },
                version: { type: :string },
                timestamp: { type: :string, format: 'date-time' }
              }
            }
          },
          required: ['success', 'data']

        run_test!
      end
    end
  end
end
```

**Generate documentation:**
```bash
# Generate Swagger YAML from specs
rake rswag:specs:swaggerize

# Expected output:
# Generating Swagger docs ...
# swagger/v1/swagger.yaml generated
```

**Access Swagger UI:**
- Start Rails server (`rails s`)
- Visit: `http://localhost:3000/api-docs`
- You'll see interactive API documentation with "Try it out" buttons

**Mount Swagger UI routes** (should be auto-added, verify in routes.rb):
```ruby
# config/routes.rb should have:
Rails.application.routes.draw do
  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'

  # ... other routes ...
end
```

---

## Phase 3: Setup Code Quality & Linting

### Step 3.1: Setup Rubocop

```bash
# Generate Rubocop config
touch .rubocop.yml

# Edit .rubocop.yml
code .rubocop.yml
```

**Add to .rubocop.yml:**
```yaml
require:
  - rubocop-rails
  - rubocop-rspec
  - rubocop-performance

AllCops:
  NewCops: enable
  TargetRubyVersion: 3.3
  Exclude:
    - 'db/schema.rb'
    - 'db/migrate/*'
    - 'bin/*'
    - 'node_modules/**/*'
    - 'vendor/**/*'

Style/Documentation:
  Enabled: false

Style/FrozenStringLiteralComment:
  Enabled: false

Metrics/BlockLength:
  Exclude:
    - 'spec/**/*'
    - 'config/environments/*'
    - 'config/routes.rb'

Layout/LineLength:
  Max: 120
```

**Run Rubocop:**
```bash
# Check code style
bundle exec rubocop

# Auto-fix issues
bundle exec rubocop -A
```

### Step 3.2: Setup Annotate

```bash
# Generate annotate config
rails g annotate:install

# This will auto-annotate models with schema info
```

---

## Phase 4: Configure CORS

### Step 4.1: Configure CORS for API

```bash
# Edit config/initializers/cors.rb
code config/initializers/cors.rb
```

**Replace dengan:**
```ruby
# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # Development: allow all origins
    origins '*'  # CHANGE in production to specific domains!

    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      expose: ['Authorization'],
      max_age: 600
  end
end
```

**Note:** Untuk production, ganti `origins '*'` dengan domain spesifik:
```ruby
# Production example:
origins 'https://your-frontend-app.com', 'https://mobile.your-app.com'
```

---

## Phase 4: Setup Redis & Sidekiq

### Step 4.1: Configure Redis

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

### Step 4.2: Configure Sidekiq

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

## Phase 5: Setup API Structure

### Step 5.1: Create API Base Controller

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

### Step 5.2: Setup Routes

```bash
# Edit config/routes.rb
code config/routes.rb
```

**Replace dengan:**
```ruby
# config/routes.rb
Rails.application.routes.draw do
  # Health check endpoint
  get "up" => "rails/health#show", as: :rails_health_check

  # API routes
  namespace :api do
    namespace :v1 do
      # Authentication routes (akan dibuat nanti)
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

### Step 5.3: Create Test Endpoint

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

### Step 5.4: Setup Blueprint Serializers

Blueprint adalah serializer yang akan kita gunakan untuk mengubah models menjadi JSON response.

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

**Create example blueprint untuk testing:**
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

**Update ping controller untuk menggunakan Blueprint:**
```bash
code app/controllers/api/v1/ping_controller.rb
```

**Update menjadi:**
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

### Step 5.5: Setup Flipper (Feature Flags)

Flipper memungkinkan Trunk-Based Development dengan feature flags.

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

**Add Flipper UI route:**
```ruby
# config/routes.rb
Rails.application.routes.draw do
  # Health check endpoint
  get "up" => "rails/health#show", as: :rails_health_check

  # Flipper UI (for development - add authentication in production!)
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

### Step 5.6: Setup ActiveAdmin (Admin Panel)

ActiveAdmin provides admin dashboard untuk user management, moderation, dan customer support.

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
# For now, we'll configure them in Phase 2
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

## Phase 6: Security & Monitoring

### Step 6.1: Setup rack-attack (Rate Limiting)

rack-attack melindungi API dari spam, brute force attacks, dan DDoS.

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

### Step 6.2: Setup dotenv-rails (Environment Variables)

dotenv-rails sudah kita install, sekarang pastikan .env file terload.

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

### Step 6.3: Setup lograge (Structured Logging)

Lograge mengubah Rails logs yang verbose menjadi single-line structured logs.

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

## Testing Your Setup

### Test 1: Start Rails Server

```bash
# Start Rails server
rails server

# atau
rails s

# Expected output:
# => Booting Puma
# => Rails 8.1.1 application starting in development
# => Run `bin/rails server --help` for more startup options
# Puma starting in single mode...
# * Listening on http://127.0.0.1:3000

# Server berjalan di http://localhost:3000
```

### Test 2: Test Endpoints

**Open new terminal tab, test dengan curl:**

```bash
# Test health check
curl http://localhost:3000/up

# Expected: status 200 OK

# Test ping endpoint
curl http://localhost:3000/api/v1/ping

# Expected output:
# {"success":true,"data":{"message":"pong","timestamp":"2025-12-25T...","version":"v1"}}
```

**Atau buka di browser:**
```
http://localhost:3000/api/v1/ping
```

### Test 3: Check Redis Connection

```bash
# Rails console
rails console

# atau
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
# atau
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
brew services start postgresql@15

# Check connection
psql -U chat_api_user -d chat_api_development
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

Setelah setup selesai, Anda bisa lanjut ke:

1. **Phase 2**: Create database migrations untuk core models (users, conversations, messages, dll)
2. **Phase 3**: Setup authentication (JWT)
3. **Phase 4**: Implement API endpoints
4. **Phase 5**: Setup ActionCable untuk real-time features

Lihat file **CHAT_API_PLAN.md** untuk detail implementation plan.

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

Jika ada error atau pertanyaan, jangan ragu untuk bertanya!
