# Chat API - Installation Guide

Complete step-by-step guide to set up the Chat API project from scratch. Follow each step to understand the setup process.

---

## Choose Your Setup Method

You have two options to set up the Chat API:

### Option 1: Docker (Quick Start) 🐳 **Recommended for Quick Setup**

**Pros:**
- ✅ Get started in minutes
- ✅ No need to install Ruby, PostgreSQL, Redis locally
- ✅ Consistent environment across team
- ✅ Works on any OS (Mac, Linux, Windows)

**Get started:**
```bash
# 1. Clone repository
git clone <your-repo-url>
cd chat-api

# 2. Start services
docker-compose up

# 3. Setup database (in another terminal)
docker-compose exec web rails db:create db:migrate

# Done! Access at http://localhost:3000
```

**📚 [Complete Docker Guide →](../deployment/docker.md)**

---

### Option 2: Manual Installation (Traditional) 🛠️ **Recommended for Learning**

**Pros:**
- ✅ Faster performance (especially on Mac)
- ✅ Better understanding of dependencies
- ✅ Easier debugging
- ✅ Native development experience

**Continue below for manual installation steps.**

---

## Prerequisites - Install Dependencies

**Note:** Skip this section if you're using Docker (Option 1).

### 1. Install Ruby 3.3+

**macOS (using rbenv - recommended):**
```bash
# Install rbenv
brew install rbenv ruby-build

# Install Ruby 3.3.0 (or latest 3.3.x)
rbenv install 3.3.0

# Set as default
rbenv global 3.3.0

# Verify
ruby -v
# Output: ruby 3.3.0 (or newer)
```

**Alternative using asdf:**
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
- **PostgreSQL 18**: Latest features, bleeding edge (newly released/beta)
- **PostgreSQL 17**: Stable, battle-tested, production-ready ✅ (Recommended)
- **PostgreSQL 16**: Very stable, widely used in production

**Note:** For development, you can use the latest version. For production, PostgreSQL 17 is recommended as it's more mature.

```bash
# Check installed version
psql --version

# If you have old version (< 16), consider upgrading:
brew upgrade postgresql
```

**Default PostgreSQL Configuration (macOS/Linux):**

Rails 8.1 uses **Unix domain socket** by default for database connections in development. This means:
- ✅ **No username/password needed** for development
- ✅ Automatically connects using system user (e.g., user `irvan` on macOS)
- ✅ Faster than TCP connection
- ✅ More secure (no network exposure)

**No need to create a dedicated PostgreSQL user!** Rails will automatically connect with your system user.

If you want to use TCP connection or custom user (optional):
```bash
# Login to psql
psql postgres

# Create user (at psql prompt)
CREATE USER chat_api_user WITH PASSWORD 'your_password' CREATEDB;

# Exit
\q

# Then uncomment host/username/password in database.yml
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

### 5. Install Node.js (for Asset Pipeline if needed)

```bash
# Install Node.js
brew install node

# Verify
node -v
npm -v
```

### 6. Install ImageMagick (for image processing)

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
# Navigate to Projects directory
cd /Users/irvan/Projects

# Create new Rails API project with PostgreSQL
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

# Flag explanations:
# --api                : API-only mode (no views, helpers, assets)
# --database=postgresql: Use PostgreSQL
# --skip-action-mailer : Skip mailer (we'll add manually later)
# --skip-active-storage: Skip active storage (we'll add manually later)
# --skip-action-cable  : Skip action cable (we'll add manually later)
# --skip-jbuilder      : Skip jbuilder (we'll use Blueprint!)
# -T                   : Skip minitest (we'll use RSpec)

# Navigate to project directory
cd chat-api
```

### Step 1.2: Update Gemfile (IMPORTANT - Do This First!)

**⚠️ IMPORTANT:** Update Gemfile BEFORE configuring database or running Rails commands!

```bash
# Open Gemfile
code Gemfile
```

**Replace with:**
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

# API Documentation
gem 'rswag-api'    # Serves OpenAPI/Swagger JSON spec
gem 'rswag-ui'     # Swagger UI for interactive API docs

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
```

### Step 1.3: Install All Gems

```bash
# Install all gems (IMPORTANT!)
bundle install

# This might take a few minutes...
# Expected output: Bundle complete! XX Gemfile dependencies, YY gems now installed.
```

**⚠️ Why bundle install here?**
- Rails new already auto runs bundle install (default gems)
- We just updated Gemfile with additional gems
- **MUST** run bundle install again before running Rails commands!
- Gems like `jwt`, `pundit`, `blueprinter` are required

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
# Open with your favorite editor (vim, nano, vscode, etc.)
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

**Create .env file for development:**
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
# Generate secret key for JWT
rails secret

# Copy output and paste to .env as JWT_SECRET_KEY
```

### Step 1.6: Create Database

**NOW** we can safely run Rails commands since gems are installed!

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

**Add Shoulda Matchers and FactoryBot configuration:**

Add this after the `ActiveRecord::Migration.maintain_test_schema!` block:

```ruby
# Shoulda Matchers configuration
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end

# FactoryBot configuration
RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
end
```

**Important:** Do NOT add DatabaseCleaner configuration. Rails transactional fixtures (already enabled by default) are simpler and faster for API-only apps.

The default `config.use_transactional_fixtures = true` in the main RSpec.configure block is perfect for our needs.

**Add SimpleCov to spec/spec_helper.rb:**
```bash
code spec/spec_helper.rb
```

**Add at the very top (line 1):**
```ruby
# SimpleCov must be loaded before application code
require 'simplecov'
SimpleCov.start 'rails' do
  add_filter '/spec/'
  add_filter '/config/'
  add_filter '/vendor/'
end
```

**Uncomment useful RSpec options:**

In `spec/spec_helper.rb`, find the section with `=begin` and `=end` (around line 49-93), and remove the `=begin` and `=end` lines to enable:
- Focus on specific tests (`:focus` tag)
- Test failure persistence
- Monkey patching prevention
- Better output for single files
- Slow test profiling
- Random test order

Or simply delete lines with `=begin` and `=end` to uncomment all recommended RSpec options.

**Support files auto-loading (optional):**

Keep the support files line commented for now:
```ruby
# Uncomment this when you create spec/support/ directory:
# Rails.root.glob('spec/support/**/*.rb').sort_by(&:to_s).each { |f| require f }
```

When you create support files later, uncomment this line.

### Step 2.3: RSpec Directory Structure (YAGNI Approach)

**Important:** Do NOT manually create spec subdirectories (models/, requests/, etc.). Rails generators will create them automatically as needed.

**Why YAGNI (You Ain't Gonna Need It)?**
- ✅ Cleaner repository (no empty directories)
- ✅ Only create what you actually use
- ✅ Rails generators handle directory creation
- ✅ No need for `.keep` files

**How it works:**

```bash
# Generate model → auto-creates spec/models/ and spec/factories/
rails generate model User email:string username:string
# Creates:
#   spec/models/user_spec.rb
#   spec/factories/users.rb

# Generate request spec → auto-creates spec/requests/
rails generate rspec:request api/v1/users
# Creates:
#   spec/requests/api/v1/users_spec.rb

# Manual creation only for custom directories (when needed)
mkdir -p spec/services
touch spec/services/message_service_spec.rb
```

**Available RSpec generators:**
```bash
rails generate rspec:model User          # Model + factory
rails generate rspec:request Users       # API request specs
rails generate rspec:controller Users    # Controller specs
rails generate rspec:job NotificationJob # Job specs
rails generate rspec:mailer UserMailer   # Mailer specs
```

**After cloning the repo:**
Someone cloning this repo just needs:
```bash
bundle install
rails db:setup
bundle exec rspec  # Should show "0 examples, 0 failures"
```

Directories will appear as they develop features. No manual setup needed!

**📚 For complete Rails generator reference:**
See **[Rails Commands](../reference/rails-commands.md)** for comprehensive examples of:
- Model, migration, controller generators
- Background jobs, mailers, channels
- Database commands and workflows
- 20+ Chat API specific examples
- Tips & tricks to maximize productivity

### Step 2.4: Verify RSpec Setup

```bash
# Run RSpec (should work without errors)
bundle exec rspec

# Expected output:
# 0 examples, 0 failures

# SimpleCov will create coverage/ directory after first run
ls coverage/
# Open coverage report
open coverage/index.html  # macOS
# or
xdg-open coverage/index.html  # Linux
```

**Add to .gitignore:**
```bash
echo "/coverage/" >> .gitignore
echo "/spec/examples.txt" >> .gitignore
```

### Step 2.5: Setup Rswag (API Documentation)

Rswag generates interactive Swagger/OpenAPI documentation from RSpec tests.

**Install Rswag (3 separate generators):**

```bash
# 1. Install API engine (serves OpenAPI spec)
rails generate rswag:api:install

# 2. Install UI engine (Swagger UI interface)
rails generate rswag:ui:install

# 3. Install specs (RSpec integration)
rails generate rswag:specs:install

# Or run all three at once:
rails generate rswag:api:install && \
rails generate rswag:ui:install && \
rails generate rswag:specs:install
```

**This creates:**
- `config/initializers/rswag_api.rb` - API engine config
- `config/initializers/rswag_ui.rb` - Swagger UI config
- `spec/swagger_helper.rb` - Main Swagger configuration
- Adds routes to `config/routes.rb`

**Optional - Silence deprecation warning:**

If you see a Thor deprecation warning, you can silence it:
```bash
# Add to ~/.zshrc or ~/.bashrc
export THOR_SILENCE_DEPRECATION=1
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
  # Specify where to output the generated swagger files
  config.openapi_root = Rails.root.join('swagger').to_s

  # Define one or more Swagger documents
  config.openapi_specs = {
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
          description: 'Development server'
        },
        {
          url: 'https://your-production-url.com',
          description: 'Production server (update this later)'
        }
      ],
      components: {
        securitySchemes: {
          bearer_auth: {
            type: :http,
            scheme: :bearer,
            bearerFormat: 'JWT',
            description: 'JWT token for authentication. Format: Bearer <token>'
          }
        }
      }
    }
  }

  # Specify the format of the output Swagger file
  config.openapi_format = :yaml
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
rails rswag:specs:swaggerize

# Or using rake (both work the same)
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

**Add to .gitignore (optional):**
```bash
# Ignore auto-generated swagger docs (or commit them to version control)
echo "/swagger" >> .gitignore
```

**Note:** You can choose to either:
- **Ignore `/swagger`** - Regenerate docs on each deployment
- **Commit `/swagger`** - Version control your API documentation

Most teams **commit swagger files** so the API docs are always in sync with the codebase.

---

## Phase 2 Summary: What You Have Now

After completing Phase 2, your RSpec setup includes:

**✅ Configured:**
- RSpec with Rails integration
- SimpleCov for code coverage
- FactoryBot for test data (`create(:user)` syntax)
- Shoulda Matchers for Rails validations/associations
- Rails transactional fixtures (fast, simple)
- Useful RSpec options (focus, randomization, profiling)
- Rswag for API documentation

**✅ What Works:**
```bash
bundle exec rspec                    # Run all tests
bundle exec rspec --tag focus        # Run focused tests
bundle exec rspec --only-failures    # Re-run failures
bundle exec rspec --profile          # Show slowest tests
open coverage/index.html             # View code coverage
open http://localhost:3000/api-docs  # View API docs
```

**✅ YAGNI Approach:**
- No empty directories (created by generators as needed)
- Clean repository
- Rails generators auto-create spec subdirectories

**✅ For New Developers:**
Just `bundle install` + `rails db:setup` + `bundle exec rspec` - everything works!

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

## Next Steps

After installation is complete, proceed to:

1. **[Configuration Guide](configuration.md)** - Configure CORS, Redis, Sidekiq, and API structure
2. **Create Database Models** - Implement core models (users, conversations, messages)
3. **Implement Authentication** - Setup JWT-based authentication
4. **Build API Endpoints** - Create RESTful API endpoints
5. **Add Real-time Features** - Setup ActionCable for WebSocket communication

See **[Project Overview](../architecture/overview.md)** for detailed implementation plan.

---

**Installation Complete! 🎉**

Your development environment is now ready. Continue to the [Configuration Guide](configuration.md) to set up CORS, Redis, and API structure.
