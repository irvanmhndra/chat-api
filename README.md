# Chat API

A modern, real-time messaging API built with Ruby on Rails 8.1.1. Inspired by Telegram, this API-only application provides comprehensive chat features including direct messaging, group chats, channels, media sharing, and real-time communication via WebSocket.

## Features

- **Direct Messaging (1-on-1)**: Private conversations between two users
- **Group Chats**: Multi-user conversations with role-based permissions
- **Channels/Broadcast**: One-to-many messaging for announcements
- **Media Sharing**: Upload and share images, files, and documents
- **Message Reactions**: React to messages with emojis
- **Message Edit/Delete**: Full message lifecycle management
- **Typing Indicators**: Real-time typing status via WebSocket
- **Read Receipts**: Message read status tracking
- **Real-time Updates**: ActionCable WebSocket integration

## Tech Stack

- **Ruby on Rails 8.1.1** (API mode)
- **Ruby 3.3+**
- **PostgreSQL 15+** - Primary database with JSONB support
- **Redis** - Cache, ActionCable adapter, session storage
- **Active Storage** - Media upload handling
- **ActionCable** - WebSocket for real-time communication
- **Sidekiq** - Background job processing
- **RSpec** - Testing framework

### Additional Tools

- **Devise** - Admin authentication (ActiveAdmin)
- **JWT** - API authentication
- **Pundit** - Authorization policies
- **Blueprinter** - Fast JSON serialization (7-10x faster than Jbuilder)
- **Flipper** - Feature flags for trunk-based development
- **ActiveAdmin** - Admin dashboard for moderation
- **Rswag** - OpenAPI documentation generation
- **Pagy** - Lightweight pagination

## Getting Started

### Prerequisites

- Ruby 3.3 or higher
- PostgreSQL 15 or higher
- Redis 7.0 or higher
- Node.js 18+ (for asset pipeline)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/chat-api.git
   cd chat-api
   ```

2. **Install dependencies**
   ```bash
   bundle install
   ```

3. **Setup database**
   ```bash
   # Development uses Unix socket by default (no password needed)
   rails db:create
   rails db:migrate
   rails db:seed
   ```

4. **Start Redis**
   ```bash
   redis-server
   ```

5. **Start Sidekiq** (in separate terminal)
   ```bash
   bundle exec sidekiq
   ```

6. **Start Rails server**
   ```bash
   rails server
   ```

The API will be available at `http://localhost:3000`

### Admin Panel

Access the admin dashboard at `http://localhost:3000/admin`:
- **Email**: admin@example.com
- **Password**: password123

For detailed setup instructions, see [Installation Guide](docs/getting-started/installation.md).

## Documentation

Comprehensive documentation is available in the `docs/` directory:

### Getting Started
- [Installation Guide](docs/getting-started/installation.md) - Complete setup instructions
- [Configuration Guide](docs/getting-started/configuration.md) - Environment and database setup

### Architecture
- [Project Overview](docs/architecture/overview.md) - System design and implementation plan
- [Security Guide](docs/architecture/security.md) - Security best practices

### Reference
- [Rails Commands](docs/reference/rails-commands.md) - Common Rails generators and commands

### Tools
- [Blueprint Guide](docs/tools/blueprint.md) - JSON serialization with Blueprinter
- [Flipper Guide](docs/tools/flipper.md) - Feature flags for trunk-based development
- [ActiveAdmin Guide](docs/tools/activeadmin.md) - Admin panel for moderation
- [Rswag Guide](docs/tools/rswag.md) - API documentation with OpenAPI

For a complete index, see [Documentation Index](docs/README.md).

## API Endpoints

### Authentication
```
POST   /api/v1/auth/register          # User registration
POST   /api/v1/auth/login             # Login
DELETE /api/v1/auth/logout            # Logout
POST   /api/v1/auth/refresh           # Refresh token
GET    /api/v1/auth/me                # Current user info
```

### Conversations
```
GET    /api/v1/conversations          # List user's conversations
POST   /api/v1/conversations          # Create conversation
GET    /api/v1/conversations/:id      # Get conversation details
PATCH  /api/v1/conversations/:id      # Update conversation
DELETE /api/v1/conversations/:id      # Delete/leave conversation
```

### Messages
```
GET    /api/v1/conversations/:cid/messages         # List messages
POST   /api/v1/conversations/:cid/messages         # Send message
PATCH  /api/v1/conversations/:cid/messages/:id     # Edit message
DELETE /api/v1/conversations/:cid/messages/:id     # Delete message
```

For complete API documentation, visit `http://localhost:3000/api-docs` (Swagger UI).

## Testing

Run the test suite:

```bash
# Run all tests
bundle exec rspec

# Run with coverage report
COVERAGE=true bundle exec rspec

# Run specific test file
bundle exec rspec spec/models/user_spec.rb

# Run focused tests
bundle exec rspec spec/models/user_spec.rb:42
```

Coverage reports are generated in `coverage/` directory.

For RSpec setup details, see [Installation Guide](docs/getting-started/installation.md#phase-2-setup-rspec).

## Development

### Code Style

This project follows Ruby community standards:
- Use [RuboCop](https://rubocop.org/) for code linting
- Follow [Rails Style Guide](https://rails.rubygems.org/rubystyle.html)

### Database

Rails 8.1 uses `max_connections` instead of `pool`:

```yaml
default: &default
  adapter: postgresql
  encoding: unicode
  max_connections: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
```

Development environment uses Unix domain socket by default (no password needed).

### Feature Flags

New features should be developed behind feature flags using Flipper:

```ruby
if Flipper.enabled?(:new_feature, current_user)
  # New feature code
else
  # Old/default behavior
end
```

See [Flipper Guide](docs/tools/flipper.md) for trunk-based development workflow.

### Rails Generators

Use Rails generators to minimize manual file creation:

```bash
# Generate model with tests and factories
rails g model Message conversation:references content:text

# Generate request spec
rails g rspec:request api/v1/messages

# Generate service object
rails g service MessageService
```

See [Rails Commands](docs/reference/rails-commands.md) for comprehensive generator examples.

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on:
- Code of Conduct
- Development workflow
- Pull request process
- Coding standards

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and release notes.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- Documentation: [docs/](docs/)
- Issues: [GitHub Issues](https://github.com/yourusername/chat-api/issues)
- Discussions: [GitHub Discussions](https://github.com/yourusername/chat-api/discussions)

## Acknowledgments

- Built with [Ruby on Rails](https://rubyonrails.org/)
- Real-time powered by [ActionCable](https://guides.rubyonrails.org/action_cable_overview.html)
- Admin panel by [ActiveAdmin](https://activeadmin.info/)
- Serialization by [Blueprinter](https://github.com/procore/blueprinter)
- Feature flags by [Flipper](https://www.flippercloud.io/)
