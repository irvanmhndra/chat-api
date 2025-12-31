# Rails Generators & Commands Guide for Chat API

Complete guide to Rails generators and commands to minimize manual file creation.

---

## Table of Contents

1. [Most Common Generators](#1-most-common-generators)
2. [Model Generators](#2-model-generators)
3. [Migration Generators](#3-migration-generators)
4. [Controller & API Generators](#4-controller--api-generators)
5. [RSpec Test Generators](#5-rspec-test-generators)
6. [Background Job Generators](#6-background-job-generators)
7. [Mailer & Channel Generators](#7-mailer--channel-generators)
8. [Database Commands](#8-database-commands)
9. [Useful Rails Commands](#9-useful-rails-commands)
10. [Destroy/Undo Commands](#10-destroyundo-commands)
11. [Tips & Tricks](#11-tips--tricks)

---

## 1. Most Common Generators

### Quick Reference

```bash
# Model (paling sering!)
rails generate model User email:string username:string

# Migration only
rails generate migration AddFieldToUsers field:type

# API Request specs
rails generate rspec:request api/v1/users

# Controller (API mode)
rails generate controller api/v1/users

# Background job
rails generate job ProcessNotification

# Mailer
rails generate mailer UserMailer

# ActionCable channel
rails generate channel Chat
```

### List All Available Generators

```bash
# See all generators
rails generate --help

# See specific generator options
rails generate model --help
rails generate migration --help
```

---

## 2. Model Generators

### Basic Model Generation

```bash
# Generate model with fields
rails generate model User email:string username:string

# Creates:
# - app/models/user.rb
# - db/migrate/xxx_create_users.rb
# - spec/models/user_spec.rb (RSpec)
# - spec/factories/users.rb (FactoryBot)
```

### Chat API Examples

**User Model:**
```bash
rails generate model User \
  email:string:uniq \
  username:string:uniq \
  display_name:string \
  bio:text \
  online_status:integer \
  last_seen_at:datetime

# :uniq adds unique index automatically
```

**Message Model:**
```bash
rails generate model Message \
  conversation:references \
  sender:references \
  content:text \
  message_type:integer \
  metadata:jsonb \
  edited_at:datetime \
  deleted_at:datetime \
  reply_to_id:bigint

# :references creates foreign key + index
# :jsonb for PostgreSQL JSON column
```

**Conversation Model (with STI):**
```bash
rails generate model Conversation \
  type:string \
  name:string \
  description:text \
  creator:references \
  settings:jsonb \
  last_message_at:datetime

# type:string enables Single Table Inheritance (STI)
```

**Participant Model:**
```bash
rails generate model Participant \
  conversation:references \
  user:references \
  role:integer \
  joined_at:datetime \
  last_read_at:datetime \
  notification_settings:jsonb
```

**Reaction Model:**
```bash
rails generate model Reaction \
  message:references \
  user:references \
  emoji:string
```

### Field Types Reference

```bash
# String & Text
field:string              # VARCHAR(255)
field:text                # TEXT (unlimited)
field:string{50}          # VARCHAR(50) custom length

# Numbers
field:integer             # 4 bytes
field:bigint              # 8 bytes (for large IDs)
field:float               # Floating point
field:decimal{10,2}       # DECIMAL(10,2) - for money

# Boolean
field:boolean             # true/false

# Date & Time
field:date                # Date only
field:time                # Time only
field:datetime            # Date + Time
field:timestamp           # Unix timestamp

# Binary & JSON
field:binary              # Binary data
field:json                # JSON (MySQL)
field:jsonb               # JSONB (PostgreSQL, indexed)

# References (Foreign Keys)
field:references          # Creates field_id + index
field:belongs_to          # Alias for references

# Arrays (PostgreSQL)
field:string:array        # String array
field:integer:array       # Integer array
```

### Modifiers

```bash
# Unique index
email:string:uniq
email:string:index:unique

# Regular index
username:string:index

# Not null
email:string{100}:uniq!

# Default value (set in migration manually)
active:boolean  # then edit migration to add default: true

# Multiple indexes (composite)
# Generate model, then create migration for composite index
```

---

## 3. Migration Generators

### Add Columns

```bash
# Add single column
rails generate migration AddAvatarUrlToUsers avatar_url:string

# Add multiple columns
rails generate migration AddDetailsToUsers \
  phone:string \
  verified:boolean \
  verified_at:datetime

# Creates migration with add_column statements
```

### Remove Columns

```bash
# Remove columns
rails generate migration RemovePhoneFromUsers phone:string

# Creates migration with remove_column
```

### Add Index

```bash
# Single column index
rails generate migration AddIndexToUsersEmail

# Then edit migration:
# add_index :users, :email

# Composite index
rails generate migration AddIndexToParticipants

# Edit migration:
# add_index :participants, [:conversation_id, :user_id], unique: true
```

### Add Foreign Key

```bash
# Add reference/foreign key
rails generate migration AddUserToMessages user:references

# Creates:
# add_reference :messages, :user, foreign_key: true
```

### Rename Column

```bash
# Generate empty migration
rails generate migration RenameUsernameToHandle

# Edit migration:
# rename_column :users, :username, :handle
```

### Change Column Type

```bash
# Generate empty migration
rails generate migration ChangeOnlineStatusToString

# Edit migration:
# change_column :users, :online_status, :string
```

### Chat API Migration Examples

**Add soft delete to messages:**
```bash
rails generate migration AddDeletedAtToMessages deleted_at:datetime:index
```

**Add composite unique index:**
```bash
rails generate migration AddUniqueIndexToReactions

# Edit migration:
def change
  add_index :reactions, [:message_id, :user_id, :emoji], unique: true, name: 'index_reactions_on_message_user_emoji'
end
```

**Add counter cache:**
```bash
rails generate migration AddMessagesCountToConversations messages_count:integer

# Edit migration:
def change
  add_column :conversations, :messages_count, :integer, default: 0, null: false

  # Backfill existing data
  reversible do |dir|
    dir.up do
      Conversation.find_each do |conversation|
        Conversation.reset_counters(conversation.id, :messages)
      end
    end
  end
end
```

---

## 4. Controller & API Generators

### Generate API Controller

```bash
# Basic API controller
rails generate controller api/v1/users

# Creates:
# - app/controllers/api/v1/users_controller.rb
# - spec/requests/api/v1/users_spec.rb (if RSpec configured)
```

### Generate with Actions

```bash
# Controller with specific actions
rails generate controller api/v1/users index show create update destroy

# Creates controller with methods:
# - index, show, create, update, destroy
# Also creates corresponding spec files
```

### Chat API Controller Examples

**Auth Controller:**
```bash
rails generate controller api/v1/auth/sessions create destroy

# Creates:
# - app/controllers/api/v1/auth/sessions_controller.rb
# - spec/requests/api/v1/auth/sessions_spec.rb
```

**Messages Controller:**
```bash
rails generate controller api/v1/conversations/messages \
  index show create update destroy

# Nested under conversations
```

**Users Controller:**
```bash
rails generate controller api/v1/users index show update
```

### Skip Options

```bash
# Skip helper (API mode biasanya ga perlu)
rails generate controller api/v1/users --no-helper

# Skip views (default di API mode)
rails generate controller api/v1/users --no-view-specs

# Skip all tests
rails generate controller api/v1/users --no-test-framework
```

---

## 5. RSpec Test Generators

### Request Specs (API Testing)

```bash
# Generate request spec
rails generate rspec:request api/v1/users

# Creates:
# - spec/requests/api/v1/users_spec.rb

# Auto-creates spec/requests/ directory
```

### Model Specs

```bash
# Generate model spec only (if not created with model)
rails generate rspec:model User

# Creates:
# - spec/models/user_spec.rb
```

### Other RSpec Generators

```bash
# Job spec
rails generate rspec:job ProcessNotification

# Mailer spec
rails generate rspec:mailer UserMailer

# Channel spec (ActionCable)
rails generate rspec:channel Chat

# Integration spec
rails generate rspec:integration user_authentication
```

### Chat API Test Examples

**Auth Request Spec:**
```bash
rails generate rspec:request api/v1/auth
```

**Message Request Spec:**
```bash
rails generate rspec:request api/v1/messages
```

**Service Spec (manual - no generator):**
```bash
# Create manually
mkdir -p spec/services
touch spec/services/message_service_spec.rb
```

---

## 6. Background Job Generators

### Generate Job

```bash
# Basic job
rails generate job ProcessNotification

# Creates:
# - app/jobs/process_notification_job.rb
# - spec/jobs/process_notification_job_spec.rb
```

### Chat API Job Examples

**Send Notification Job:**
```bash
rails generate job SendNotification
```

**Process Media Job:**
```bash
rails generate job ProcessMedia
```

**Cleanup Deleted Messages Job:**
```bash
rails generate job CleanupDeletedMessages
```

**Job Template:**
```ruby
# app/jobs/send_notification_job.rb
class SendNotificationJob < ApplicationJob
  queue_as :default

  def perform(user_id, message)
    # Send notification logic
    user = User.find(user_id)
    NotificationService.send_to(user, message)
  end
end
```

---

## 7. Mailer & Channel Generators

### Generate Mailer

```bash
# Mailer with actions
rails generate mailer UserMailer welcome reset_password

# Creates:
# - app/mailers/user_mailer.rb
# - app/views/user_mailer/welcome.html.erb
# - app/views/user_mailer/welcome.text.erb
# - app/views/user_mailer/reset_password.html.erb
# - app/views/user_mailer/reset_password.text.erb
# - spec/mailers/user_mailer_spec.rb
```

### Generate ActionCable Channel

```bash
# Generate channel
rails generate channel Chat

# Creates:
# - app/channels/chat_channel.rb
# - spec/channels/chat_channel_spec.rb
```

### Chat API Channel Examples

**Chat Channel:**
```bash
rails generate channel Chat conversation_id:integer
```

**Typing Indicator Channel:**
```bash
rails generate channel Typing
```

**Presence Channel:**
```bash
rails generate channel Presence
```

**Channel Template:**
```ruby
# app/channels/chat_channel.rb
class ChatChannel < ApplicationCable::Channel
  def subscribed
    conversation = Conversation.find(params[:conversation_id])
    stream_for conversation
  end

  def unsubscribed
    # Cleanup
  end

  def receive(data)
    # Handle incoming messages
  end
end
```

---

## 8. Database Commands

### Migration Commands

```bash
# Run pending migrations
rails db:migrate

# Rollback last migration
rails db:rollback

# Rollback specific number of migrations
rails db:rollback STEP=3

# Redo last migration (rollback + migrate)
rails db:migrate:redo

# Rollback to specific version
rails db:migrate:down VERSION=20231225120000

# Check migration status
rails db:migrate:status

# Run migrations for specific environment
RAILS_ENV=test rails db:migrate
```

### Database Setup Commands

```bash
# Create database
rails db:create

# Drop database
rails db:drop

# Create + migrate
rails db:setup

# Drop + create + migrate + seed
rails db:reset

# Load schema (faster than migrate)
rails db:schema:load

# Seed database
rails db:seed
```

### Database Inspection

```bash
# Database console
rails dbconsole
# or
rails db

# Show schema version
rails db:version

# Dump schema to file
rails db:schema:dump
```

### Test Database

```bash
# Prepare test database (load schema)
rails db:test:prepare

# Clone development to test
rails db:test:clone
```

---

## 9. Useful Rails Commands

### Server & Console

```bash
# Start server
rails server
rails s

# Start on different port
rails s -p 3001

# Start in production mode
RAILS_ENV=production rails s

# Console
rails console
rails c

# Production console
RAILS_ENV=production rails c

# Sandbox console (rollback on exit)
rails c --sandbox
```

### Routes

```bash
# Show all routes
rails routes

# Filter routes
rails routes | grep user
rails routes -g user

# Show routes for specific controller
rails routes -c users

# Expanded format
rails routes --expanded
```

### Code Execution

```bash
# Run Ruby code
rails runner "puts User.count"

# Run script file
rails runner scripts/cleanup.rb

# Load Rails environment only
rails runner -e production "User.last"
```

### Information

```bash
# Rails version
rails --version
rails -v

# App statistics
rails stats

# List middleware
rails middleware

# Show configuration
rails runner "puts Rails.application.config.inspect"
```

### Maintenance

```bash
# Clear cache
rails tmp:clear

# Clear logs
rails log:clear

# Clear all temporary files
rails tmp:cache:clear
rails tmp:sessions:clear
rails tmp:sockets:clear

# Restart server (touch this file)
touch tmp/restart.txt
```

### Assets (jika ada)

```bash
# Precompile assets
rails assets:precompile

# Clean assets
rails assets:clean
rails assets:clobber
```

---

## 10. Destroy/Undo Commands

### Destroy Generated Files

```bash
# Undo model generation
rails destroy model User

# Undo controller generation
rails destroy controller api/v1/users

# Undo migration (then delete migration file)
rails db:rollback
rm db/migrate/xxx_create_users.rb

# Undo job
rails destroy job ProcessNotification

# Undo mailer
rails destroy mailer UserMailer

# Undo channel
rails destroy channel Chat
```

### What Gets Deleted

```bash
# Example: rails destroy model User
# Deletes:
# - app/models/user.rb
# - spec/models/user_spec.rb
# - spec/factories/users.rb
# - db/migrate/xxx_create_users.rb (YOU MUST DELETE MANUALLY!)

# Migration NOT auto-deleted for safety!
```

### Safe Workflow

```bash
# 1. Generate with --pretend (dry run)
rails generate model User email:string --pretend

# 2. If looks good, generate for real
rails generate model User email:string

# 3. If mistake, destroy immediately
rails destroy model User
rm db/migrate/xxx_create_users.rb
```

---

## 11. Tips & Tricks

### Dry Run (Preview)

```bash
# See what will be created without creating
rails generate model User email:string --pretend
rails g model User email:string -p  # shortcut

# Preview output:
#       invoke  active_record
#       create    db/migrate/xxx_create_users.rb
#       create    app/models/user.rb
#       invoke    rspec
#       create      spec/models/user_spec.rb
#       invoke      factory_bot
#       create        spec/factories/users.rb
```

### Skip Specific Files

```bash
# Skip migration
rails g model User email:string --no-migration

# Skip specs
rails g model User email:string --no-test-framework

# Skip factory
rails g model User email:string --skip-factory

# Multiple skips
rails g controller Users --no-helper --no-assets --no-view-specs
```

### Force Overwrite

```bash
# Force overwrite existing files
rails g model User email:string --force
rails g model User email:string -f

# Skip overwrite (keep existing)
rails g model User email:string --skip
rails g model User email:string -s
```

### Generator Shortcuts

```bash
# 'generate' → 'g'
rails g model User
rails g controller Users
rails g migration AddEmailToUsers

# 'destroy' → 'd'
rails d model User
rails d controller Users
```

### Template Customization

Create custom generators in `lib/templates/`:

```bash
# Custom model template
lib/templates/active_record/model/model.rb.tt

# Custom controller template
lib/templates/rails/controller/controller.rb.tt
```

### Batch Generation

```bash
# Generate multiple models at once
rails g model User email:string username:string
rails g model Message content:text user:references
rails g model Conversation name:string

# Or use script:
# scripts/generate_models.sh
#!/bin/bash
rails g model User email:string username:string
rails g model Message content:text user:references
rails g model Conversation name:string
```

### Interactive Mode

```bash
# Rails will ask before overwriting
rails g model User email:string
# (if file exists, Rails asks: overwrite? [Ynaqdhm])

# y - yes, overwrite
# n - no, skip
# a - all, overwrite all
# q - quit
# d - diff, show differences
# h - help
```

### Check What Generator Will Create

```bash
# Use --pretend to preview
rails g model User email:string username:string --pretend

# Then copy-paste without --pretend to actually generate
rails g model User email:string username:string
```

---

## Common Chat API Workflows

### 1. Create User System

```bash
# 1. Generate User model
rails g model User \
  email:string:uniq \
  username:string:uniq \
  encrypted_password:string \
  display_name:string \
  bio:text \
  online_status:integer \
  last_seen_at:datetime

# 2. Run migration
rails db:migrate

# 3. Generate Auth controller
rails g controller api/v1/auth/sessions create destroy

# 4. Generate request specs
rails g rspec:request api/v1/auth

# 5. Add validations to model manually
# 6. Add authentication logic to controller
```

### 2. Create Messaging System

```bash
# 1. Generate Conversation model
rails g model Conversation \
  type:string:index \
  name:string \
  description:text \
  creator:references \
  settings:jsonb \
  last_message_at:datetime

# 2. Generate Message model
rails g model Message \
  conversation:references \
  sender:references \
  content:text \
  message_type:integer \
  metadata:jsonb \
  edited_at:datetime \
  deleted_at:datetime:index

# 3. Generate Participant model
rails g model Participant \
  conversation:references \
  user:references \
  role:integer \
  joined_at:datetime \
  last_read_at:datetime

# 4. Run migrations
rails db:migrate

# 5. Generate controllers
rails g controller api/v1/conversations index show create update destroy
rails g controller api/v1/messages index show create update destroy

# 6. Generate request specs
rails g rspec:request api/v1/conversations
rails g rspec:request api/v1/messages
```

### 3. Add Real-time Features

```bash
# 1. Generate channels
rails g channel Chat
rails g channel Typing
rails g channel Presence

# 2. Generate jobs
rails g job BroadcastMessage
rails g job SendNotification

# 3. Implement channel logic manually
```

### 4. Add Background Processing

```bash
# 1. Generate jobs
rails g job ProcessMedia
rails g job SendPushNotification
rails g job CleanupOldMessages

# 2. Implement job logic
# 3. Queue jobs from controllers/models
```

---

## Quick Command Reference Card

```bash
# === MODELS ===
rails g model User email:string                    # Create model
rails d model User                                  # Destroy model

# === MIGRATIONS ===
rails g migration AddFieldToUsers field:type       # Add column
rails g migration RemoveFieldFromUsers field:type  # Remove column
rails db:migrate                                    # Run migrations
rails db:rollback                                   # Undo last migration

# === CONTROLLERS ===
rails g controller api/v1/users                    # Create controller
rails d controller api/v1/users                    # Destroy controller

# === SPECS ===
rails g rspec:request api/v1/users                 # Request spec
rails g rspec:model User                           # Model spec

# === JOBS ===
rails g job ProcessNotification                    # Background job
rails d job ProcessNotification                    # Destroy job

# === CHANNELS ===
rails g channel Chat                               # WebSocket channel
rails d channel Chat                               # Destroy channel

# === DATABASE ===
rails db:create                                    # Create DB
rails db:migrate                                   # Run migrations
rails db:rollback                                  # Undo migration
rails db:reset                                     # Drop + recreate + migrate
rails db:seed                                      # Seed data

# === SERVER ===
rails s                                            # Start server
rails c                                            # Console
rails routes                                       # Show routes

# === UTILITIES ===
rails g --help                                     # List generators
rails g model --help                               # Generator options
rails --version                                    # Rails version
```

---

## Summary

**Key Takeaways:**

1. ✅ **Always use generators** - Don't create files manually
2. ✅ **Use --pretend** to preview before generating
3. ✅ **Leverage :references** for associations (auto foreign keys)
4. ✅ **Use :uniq** for unique indexes
5. ✅ **Use :jsonb** for PostgreSQL JSON columns
6. ✅ **RSpec specs auto-created** with models/controllers
7. ✅ **FactoryBot factories auto-created** with models
8. ✅ **Destroy command reverses generate** (except migrations!)
9. ✅ **Shortcuts:** `rails g` = `rails generate`, `rails d` = `rails destroy`
10. ✅ **Check migration status:** `rails db:migrate:status`

**Remember:**
- Generators save time and prevent typos
- Migrations are reversible (use `rails db:rollback`)
- Always run `rails db:migrate` after generating models/migrations
- Use `--pretend` when unsure
- Destroy + regenerate if you make mistakes

---

**Happy Generating! 🚀**

Dengan generators, kamu bisa scaffold Chat API dalam hitungan menit, bukan jam!
