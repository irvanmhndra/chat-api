# Chat Messaging API - Implementation Plan

## 1. Project Overview

A Telegram-like chat messaging API built with Ruby on Rails 8.1.1. This is an API-only (headless) application with real-time messaging features using WebSocket.

### Main Features
- **Direct Messaging (1-on-1)**: Private chat between two users
- **Group Chat**: Multi-user chat conversations
- **Channels/Broadcast**: One-to-many messaging
- **Media Sharing**: Upload and share images, files, documents
- **Message Reactions**: React to messages with emoji
- **Message Edit/Delete**: Edit or delete messages
- **Typing Indicators**: Real-time typing status when user is typing
- **Read Receipts**: Message read status tracking

---

## 2. Tech Stack

### Core Framework
- **Ruby on Rails 8.1.1** (API mode)
- **Ruby 3.3+** (latest stable)

### Database & Storage
- **PostgreSQL 17+** (latest: 18): Primary database
  - JSONB support untuk metadata
  - Full-text search capabilities
  - Scalable untuk production
  - Performance improvements di latest version
  - Recommended: PostgreSQL 17 (stable) atau 18 (latest)
- **Redis**:
  - Cache layer
  - ActionCable adapter untuk WebSocket
  - Session storage
  - Presence tracking
- **Active Storage**: File/media upload handling
  - Local storage untuk development
  - S3-compatible storage untuk production (Amazon S3, MinIO, dll)

### Real-time Communication
- **ActionCable**: WebSocket implementation Rails native
- **Redis Adapter**: Untuk multi-server deployment

### Authentication & Authorization
- **Devise** atau **JWT (json-jwt)**: User authentication
- **Pundit**: Authorization policies
- **BCrypt**: Password encryption (built-in Rails)

### Background Jobs
- **Sidekiq**: Background job processing
  - Notification delivery
  - Media processing
  - Cleanup tasks

### API & Serialization
- **Blueprinter**: Modern, fast JSON serializer (7-10x faster than Jbuilder/AMS)
- **Oj**: High-performance JSON parser

### Security & Rate Limiting
- **rack-attack**: Rate limiting & throttling
  - Prevent spam and brute force attacks
  - API request throttling
  - IP blocklisting/allowlisting
  - Protection against DDoS

### Environment & Configuration
- **dotenv-rails**: Environment variable management
  - Load .env files in development/test
  - Secure secrets management
  - Configuration isolation

### Logging & Monitoring
- **Lograge**: Structured, clean logging
  - Single-line log entries
  - JSON formatting support
  - Better production log analysis
  - Reduces log noise

### API Documentation
- **Rswag**: Automated API documentation (OpenAPI/Swagger)
  - Auto-generated from RSpec tests
  - Interactive Swagger UI
  - Test-driven documentation (always in sync)
  - OpenAPI 3.0 specification

### Feature Flags (TBD/Continuous Deployment)
- **Flipper**: Feature flags/toggles
  - Progressive rollouts
  - A/B testing
  - Dark launches
  - Kill switches
- **Flipper Active Record**: PostgreSQL storage adapter
- **Flipper UI**: Web-based flag management dashboard

### Admin Panel (Backoffice/Moderation)
- **ActiveAdmin**: Admin dashboard & CRUD interface
  - User management
  - Content moderation
  - Customer support tools
  - Analytics & reporting
  - Message/conversation monitoring

---

## 3. Arsitektur Aplikasi

### A. Layer Architecture

```
┌─────────────────────────────────────────┐
│           Client Applications           │
│     (Web, Mobile, Desktop - Separate)   │
└─────────────────┬───────────────────────┘
                  │
        ┌─────────┴──────────┐
        │                    │
        ▼                    ▼
┌──────────────┐    ┌──────────────────┐
│  REST API    │    │   WebSocket      │
│  (HTTP/JSON) │    │  (ActionCable)   │
└──────┬───────┘    └────────┬─────────┘
       │                     │
       └──────────┬──────────┘
                  │
         ┌────────▼─────────┐
         │   Application    │
         │   Layer          │
         │  - Controllers   │
         │  - Services      │
         │  - Jobs          │
         └────────┬─────────┘
                  │
         ┌────────▼─────────┐
         │   Domain Layer   │
         │  - Models        │
         │  - Policies      │
         │  - Validators    │
         └────────┬─────────┘
                  │
    ┌─────────────┼─────────────┐
    │             │             │
    ▼             ▼             ▼
┌─────────┐  ┌─────────┐  ┌─────────┐
│PostgreSQL│  │  Redis  │  │ Storage │
└─────────┘  └─────────┘  └─────────┘
```

### B. Module Structure

```
app/
├── channels/          # ActionCable channels
│   ├── chat_channel.rb
│   ├── typing_channel.rb
│   └── presence_channel.rb
├── controllers/
│   ├── api/
│   │   └── v1/
│   │       ├── auth/
│   │       ├── chats/
│   │       ├── messages/
│   │       ├── users/
│   │       └── media/
├── models/
│   ├── user.rb
│   ├── conversation.rb
│   ├── message.rb
│   ├── participant.rb
│   ├── reaction.rb
│   └── attachment.rb
├── services/          # Business logic
│   ├── message_service.rb
│   ├── conversation_service.rb
│   └── notification_service.rb
├── jobs/
│   ├── notification_job.rb
│   └── media_processing_job.rb
└── policies/          # Authorization
    ├── conversation_policy.rb
    └── message_policy.rb
```

---

## 4. Database Schema

### Core Tables

#### users
```ruby
- id: bigint (PK)
- email: string (unique, indexed)
- encrypted_password: string
- username: string (unique, indexed)
- display_name: string
- avatar_url: string
- bio: text
- last_seen_at: datetime
- online_status: enum (online, offline, away)
- created_at: datetime
- updated_at: datetime
```

#### conversations
```ruby
- id: bigint (PK)
- type: string (DirectConversation, GroupChat, Channel)
- name: string (nullable untuk DM)
- description: text
- avatar_url: string
- creator_id: bigint (FK -> users)
- settings: jsonb (notification_settings, permissions, dll)
- last_message_at: datetime (indexed)
- created_at: datetime
- updated_at: datetime

Indexes:
- type
- creator_id
- last_message_at
```

#### participants
```ruby
- id: bigint (PK)
- conversation_id: bigint (FK -> conversations)
- user_id: bigint (FK -> users)
- role: enum (owner, admin, member, subscriber)
- joined_at: datetime
- last_read_at: datetime
- notification_settings: jsonb
- created_at: datetime
- updated_at: datetime

Indexes:
- [conversation_id, user_id] (unique)
- user_id
- role
```

#### messages
```ruby
- id: bigint (PK)
- conversation_id: bigint (FK -> conversations, indexed)
- sender_id: bigint (FK -> users, indexed)
- content: text
- message_type: enum (text, image, file, system)
- metadata: jsonb (mentions, links, formatting)
- edited_at: datetime
- deleted_at: datetime (soft delete)
- reply_to_id: bigint (FK -> messages, nullable)
- created_at: datetime (indexed)
- updated_at: datetime

Indexes:
- conversation_id
- sender_id
- created_at
- [conversation_id, created_at] (composite)
```

#### reactions
```ruby
- id: bigint (PK)
- message_id: bigint (FK -> messages)
- user_id: bigint (FK -> users)
- emoji: string
- created_at: datetime

Indexes:
- [message_id, user_id, emoji] (unique)
```

#### read_receipts
```ruby
- id: bigint (PK)
- message_id: bigint (FK -> messages)
- user_id: bigint (FK -> users)
- read_at: datetime
- created_at: datetime

Indexes:
- [message_id, user_id] (unique)
- user_id
```

#### attachments (Active Storage)
```ruby
Menggunakan Active Storage tables (active_storage_blobs, active_storage_attachments)
- messages.has_many_attached :files
```

---

## 5. API Endpoints

### Authentication
```
POST   /api/v1/auth/register          # User registration
POST   /api/v1/auth/login             # Login
DELETE /api/v1/auth/logout            # Logout
POST   /api/v1/auth/refresh           # Refresh token
GET    /api/v1/auth/me                # Current user info
```

### Users
```
GET    /api/v1/users                  # Search users
GET    /api/v1/users/:id              # User profile
PATCH  /api/v1/users/:id              # Update profile
PUT    /api/v1/users/:id/avatar       # Upload avatar
```

### Conversations
```
GET    /api/v1/conversations          # List user's conversations
POST   /api/v1/conversations          # Create conversation (DM/Group/Channel)
GET    /api/v1/conversations/:id      # Get conversation details
PATCH  /api/v1/conversations/:id      # Update conversation
DELETE /api/v1/conversations/:id      # Delete/leave conversation

# Participants
GET    /api/v1/conversations/:id/participants      # List participants
POST   /api/v1/conversations/:id/participants      # Add participant
DELETE /api/v1/conversations/:id/participants/:uid # Remove participant
PATCH  /api/v1/conversations/:id/participants/:uid # Update role
```

### Messages
```
GET    /api/v1/conversations/:cid/messages         # List messages (paginated)
POST   /api/v1/conversations/:cid/messages         # Send message
GET    /api/v1/conversations/:cid/messages/:id     # Get message
PATCH  /api/v1/conversations/:cid/messages/:id     # Edit message
DELETE /api/v1/conversations/:cid/messages/:id     # Delete message

# Reactions
POST   /api/v1/messages/:id/reactions              # Add reaction
DELETE /api/v1/messages/:id/reactions/:emoji       # Remove reaction

# Read Receipts
POST   /api/v1/messages/:id/read                   # Mark as read
GET    /api/v1/messages/:id/receipts               # Get read receipts
```

### Media/Attachments
```
POST   /api/v1/media/upload           # Upload file (returns signed URL)
GET    /api/v1/media/:id              # Get file info
```

### WebSocket Channels (ActionCable)
```
ChatChannel
- subscribe(conversation_id)
- receive_message
- send_message
- message_edited
- message_deleted

TypingChannel
- subscribe(conversation_id)
- start_typing
- stop_typing

PresenceChannel
- subscribe
- user_online
- user_offline
- user_away
```

---

## 6. Implementation Plan

### Phase 1: Project Setup
1. **Create new Rails 8.1.1 API project**
   ```bash
   rails new chat-api --api --database=postgresql
   ```

2. **Setup dependencies**
   - Configure PostgreSQL database
   - Install and configure Redis
   - Setup Active Storage
   - Configure CORS

3. **Add essential gems**
   ```ruby
   # Gemfile additions
   gem 'devise'               # or jwt
   gem 'pundit'
   gem 'sidekiq'
   gem 'redis'
   gem 'rack-cors'
   gem 'pagy'                 # Pagination
   gem 'image_processing'     # Image variants

   group :development, :test do
     gem 'rspec-rails'
     gem 'factory_bot_rails'
     gem 'faker'
   end
   ```

### Phase 2: Core Models & Database
1. **Create migrations**
   - Users table (if not using Devise)
   - Conversations table (with STI for types)
   - Participants table
   - Messages table
   - Reactions table
   - Read receipts table

2. **Define models & associations**
   ```ruby
   User
     has_many :participants
     has_many :conversations, through: :participants
     has_many :messages
     has_many :reactions

   Conversation (STI base)
     has_many :participants
     has_many :users, through: :participants
     has_many :messages

   DirectConversation < Conversation
   GroupChat < Conversation
   Channel < Conversation

   Message
     belongs_to :conversation
     belongs_to :sender (User)
     has_many :reactions
     has_many :read_receipts
     has_many_attached :files

   Participant
     belongs_to :user
     belongs_to :conversation
   ```

3. **Add validations & callbacks**
   - Message content presence
   - Conversation participant limits
   - Direct conversation has exactly 2 participants
   - Soft delete implementation

### Phase 3: Authentication & Authorization
1. **Setup authentication**
   - JWT-based authentication
   - Token generation & validation
   - Refresh token mechanism

2. **Setup authorization with Pundit**
   - ConversationPolicy (can view, edit, delete, add members)
   - MessagePolicy (can send, edit, delete own messages)
   - ParticipantPolicy (role-based permissions)

3. **API versioning setup**
   - Namespace API::V1
   - Version headers support

### Phase 4: REST API Implementation
1. **Authentication endpoints**
   - Register, login, logout, refresh

2. **Conversations CRUD**
   - Create different conversation types
   - List with filtering & pagination
   - Update conversation settings
   - Participant management

3. **Messages CRUD**
   - Send message with attachments
   - Edit message
   - Delete message (soft delete)
   - Pagination with cursor-based approach

4. **Reactions & Read Receipts**
   - Add/remove reactions
   - Mark messages as read
   - Get read status

### Phase 5: File Upload & Media Handling
1. **Configure Active Storage**
   - Local storage for development
   - S3 configuration for production
   - Image variants processing

2. **Media endpoints**
   - Direct upload support
   - File validation (size, type)
   - Thumbnail generation for images

### Phase 6: Real-time Features (ActionCable)
1. **Setup ActionCable**
   - Configure Redis adapter
   - Connection authentication

2. **ChatChannel**
   - Subscribe to conversation
   - Broadcast new messages
   - Broadcast message edits/deletes
   - Handle reactions in real-time

3. **TypingChannel**
   - Broadcast typing indicators
   - Auto-stop after timeout

4. **PresenceChannel**
   - Track online users
   - Broadcast presence changes
   - Last seen tracking

### Phase 7: Background Jobs
1. **Notification jobs**
   - Push notification preparation
   - Email notifications

2. **Media processing**
   - Image optimization
   - Thumbnail generation
   - Video transcoding (future)

3. **Cleanup jobs**
   - Delete old soft-deleted messages
   - Clean up orphaned files

### Phase 8: Optimization & Performance
1. **Database optimization**
   - Add proper indexes
   - Query optimization with eager loading
   - Counter caches for unread counts

2. **Caching strategy**
   - Fragment caching for user data
   - Redis caching for frequent queries
   - HTTP caching headers

3. **Pagination**
   - Cursor-based pagination for messages
   - Efficient infinite scroll support

### Phase 9: Testing
1. **Model tests**
   - Validation tests
   - Association tests
   - Callback tests

2. **Request specs**
   - API endpoint testing
   - Authentication & authorization
   - Edge cases

3. **Channel tests**
   - WebSocket connection tests
   - Broadcast tests

### Phase 10: Documentation & Deployment
1. **API documentation**
   - OpenAPI/Swagger documentation
   - Example requests/responses
   - Authentication guide

2. **Deployment setup**
   - Docker configuration
   - Environment variables
   - Database migrations strategy
   - CI/CD pipeline

---

## 7. Key Dependencies (Gemfile)

```ruby
# Core
gem 'rails', '~> 8.1.1'
gem 'pg', '~> 1.1'
gem 'puma', '>= 5.0'

# Authentication & Authorization
gem 'jwt'
gem 'bcrypt', '~> 3.1.7'
gem 'pundit'

# Redis & Background Jobs
gem 'redis', '>= 4.0'
gem 'sidekiq'

# File Upload
gem 'image_processing', '~> 1.2'

# API & Serialization
gem 'blueprinter'  # Modern, fast JSON serializer (7-10x faster than Jbuilder)
gem 'oj'           # Fast JSON parser (used by Blueprint)
gem 'rack-cors'
gem 'pagy'

# Security & Rate Limiting
gem 'rack-attack'  # Rate limiting & throttling (prevent spam, brute force, DDoS)

# Environment & Configuration
gem 'dotenv-rails'  # Load environment variables from .env file

# Logging
gem 'lograge'  # Clean, structured logging (single-line logs)

# Feature Flags (Trunk-Based Development)
gem 'flipper'
gem 'flipper-active_record'  # Store flags in PostgreSQL
gem 'flipper-ui'             # Web UI for managing flags

# Admin Panel
gem 'activeadmin'            # Admin dashboard
gem 'devise'                 # Authentication (required by ActiveAdmin)
gem 'sassc-rails'           # Sass compiler for ActiveAdmin styles

# Development & Testing
group :development, :test do
  gem 'rspec-rails', '~> 6.0'
  gem 'factory_bot_rails'
  gem 'faker'
  gem 'pry-rails'
  gem 'bullet'  # N+1 detection

  # API Documentation
  gem 'rswag'  # Swagger/OpenAPI docs from RSpec tests

  # Code Quality & Linting
  gem 'rubocop', require: false
  gem 'rubocop-rails', require: false
  gem 'rubocop-rspec', require: false
  gem 'rubocop-performance', require: false
  gem 'brakeman'  # Security vulnerability scanner
end

group :development do
  gem 'annotate'  # Schema annotations
  gem 'bundler-audit'  # Check for vulnerable dependencies
end

group :test do
  gem 'shoulda-matchers'
  gem 'simplecov', require: false
  gem 'database_cleaner-active_record'
end
```

---

## 8. Pertimbangan Keamanan

1. **Authentication**
   - JWT dengan expiration time
   - Refresh token rotation
   - Rate limiting untuk login attempts

2. **Authorization**
   - Pundit policies untuk setiap resource
   - Row-level security checks
   - Admin vs member permissions

3. **Input Validation**
   - Strong parameters
   - Content sanitization
   - File upload validation (type, size, malware scan)

4. **Data Privacy**
   - Encrypted sensitive data
   - GDPR compliance (data export, deletion)
   - Message retention policies

5. **API Security**
   - CORS configuration
   - Rate limiting (rack-attack)
   - SQL injection prevention
   - XSS prevention

---

## 9. Scalability Considerations

1. **Database**
   - Proper indexing strategy
   - Partitioning untuk messages table (by time)
   - Read replicas untuk scaling reads

2. **Caching**
   - Redis untuk session & cache
   - CDN untuk media files
   - Fragment caching

3. **WebSocket**
   - Redis adapter untuk multi-server
   - Connection pooling
   - Graceful degradation

4. **Background Jobs**
   - Sidekiq horizontal scaling
   - Job prioritization
   - Dead letter queue handling

---

## 10. Monitoring & Observability

1. **Logging**
   - Structured logging (Lograge)
   - Request/response logging
   - Error tracking (Sentry/Rollbar)

2. **Metrics**
   - APM (New Relic/DataDog)
   - WebSocket connection metrics
   - Database query performance

3. **Health Checks**
   - Database connectivity
   - Redis connectivity
   - Storage availability

---

## Estimasi Timeline

Untuk 1 developer:
- **Phase 1-2**: Setup & Core Models (3-4 hari)
- **Phase 3**: Auth & Authorization (2-3 hari)
- **Phase 4**: REST API (5-7 hari)
- **Phase 5**: File Upload (2-3 hari)
- **Phase 6**: Real-time Features (4-5 hari)
- **Phase 7**: Background Jobs (2-3 hari)
- **Phase 8**: Optimization (3-4 hari)
- **Phase 9**: Testing (4-5 hari)
- **Phase 10**: Documentation & Deploy (2-3 hari)

**Total**: ~4-6 minggu untuk MVP lengkap

---

## Next Steps

1. Review rencana ini dan berikan feedback
2. Mulai implementasi dari Phase 1
3. Iterasi berdasarkan kebutuhan
