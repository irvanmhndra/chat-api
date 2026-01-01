# Chat API Documentation

Welcome to the Chat API documentation! This directory contains comprehensive guides, references, and architectural documentation for the Chat API project.

## Quick Links

- [Project README](../README.md) - Project overview and quick start
- [Contributing Guide](../CONTRIBUTING.md) - How to contribute
- [Changelog](../CHANGELOG.md) - Version history and release notes

---

## Documentation Structure

### Getting Started

Essential guides for setting up and configuring the project:

- **[Installation Guide](getting-started/installation.md)** - Step-by-step setup instructions
  - Prerequisites and dependencies
  - Database setup (PostgreSQL with Unix socket)
  - RSpec testing framework setup
  - Redis and Sidekiq configuration
  - Running the development server

- **[Configuration Guide](getting-started/configuration.md)** - Environment and configuration
  - Database configuration (Rails 8.1 `max_connections`)
  - Environment variables (.env setup)
  - Redis and ActionCable configuration
  - Active Storage setup

### Deployment

Production deployment guides:

- **[Docker Guide](deployment/docker.md)** - Containerized development and deployment
  - Quick start with docker-compose
  - Development environment setup
  - Production Dockerfile optimization
  - Deployment to Railway, Render, Fly.io, Kamal
  - Docker commands reference
  - Troubleshooting and best practices

### Architecture

High-level design and system architecture:

- **[Project Overview](architecture/overview.md)** - Complete implementation plan
  - System architecture and design
  - Database schema and relationships
  - API endpoints specification
  - Phase-by-phase implementation plan
  - Technology stack decisions
  - Scalability considerations

- **[Security Guide](architecture/security.md)** - Security best practices
  - Authentication strategies (Devise + JWT)
  - Authorization with Pundit
  - Input validation and sanitization
  - Data privacy and GDPR compliance
  - API security measures

### Reference

Command references and API documentation:

- **[Rails Commands](reference/rails-commands.md)** - Rails generators and CLI
  - Model, migration, and controller generators
  - RSpec test generators
  - Background job generators
  - Database commands (migrate, rollback, reset)
  - Scaffolding best practices
  - YAGNI approach to file creation

### Tools & Libraries

In-depth guides for specific tools and libraries:

- **[Blueprint](tools/blueprint.md)** - JSON serialization guide
  - 7-10x faster than Jbuilder
  - Multiple views for different representations
  - Associations and nested data
  - Performance optimization tips
  - Real-world Chat API examples

- **[Flipper](tools/flipper.md)** - Feature flags guide
  - Trunk-based development workflow
  - Progressive rollouts (10% → 50% → 100%)
  - Kill switches for emergency disables
  - A/B testing strategies
  - Dark launches and testing in production
  - Feature flag lifecycle management

- **[ActiveAdmin](tools/activeadmin.md)** - Admin panel guide
  - User management and moderation
  - Message content moderation
  - Customer support workflows
  - Custom actions and batch operations
  - CSV export for analytics
  - Security best practices

- **[Rswag](tools/rswag.md)** - API documentation guide
  - OpenAPI/Swagger documentation
  - Interactive API documentation
  - Request/response examples
  - Authentication documentation
  - Generating and maintaining docs

---

## Documentation by Use Case

### I want to...

#### Set up the project for the first time

**Option 1: Docker (Quick Start)**
1. Follow [Docker Guide](deployment/docker.md) quick start
2. Run `docker-compose up` and you're ready!

**Option 2: Manual Installation**
1. Start with [Installation Guide](getting-started/installation.md)
2. Review [Configuration Guide](getting-started/configuration.md)
3. Check [Project Overview](architecture/overview.md) to understand the architecture

#### Develop a new feature
1. Read [Rails Commands](reference/rails-commands.md) for generator shortcuts
2. Use [Flipper Guide](tools/flipper.md) to implement behind feature flag
3. Use [Blueprint Guide](tools/blueprint.md) for API serialization
4. Follow [Contributing Guide](../CONTRIBUTING.md) for PR process

#### Moderate content or manage users
1. Access admin panel at `http://localhost:3000/admin`
2. Follow [ActiveAdmin Guide](tools/activeadmin.md) for moderation workflows

#### Document API changes
1. Update Rswag specs following [Rswag Guide](tools/rswag.md)
2. Run `rake rswag:specs:swaggerize` to regenerate OpenAPI docs

#### Optimize performance
1. Review [Blueprint Guide](tools/blueprint.md) for serialization optimization
2. Check [Project Overview](architecture/overview.md#scalability-considerations)

#### Deploy to production
1. Review [Security Guide](architecture/security.md)
2. Check environment configuration in [Configuration Guide](getting-started/configuration.md)
3. Review deployment considerations in [Project Overview](architecture/overview.md)

---

## Key Technologies

### Core Stack
- **Ruby on Rails 8.1.1** - API-only framework
- **PostgreSQL 15+** - Primary database
- **Redis** - Cache & ActionCable adapter
- **Sidekiq** - Background job processing

### Authentication & Authorization
- **Devise** - Admin authentication (AdminUser model)
- **JWT** - API authentication (User model)
- **Pundit** - Authorization policies

### API & Serialization
- **Blueprinter** - Fast JSON serialization
- **Pagy** - Lightweight pagination
- **Rswag** - OpenAPI documentation

### Development Tools
- **Flipper** - Feature flags
- **ActiveAdmin** - Admin dashboard
- **RSpec** - Testing framework
- **SimpleCov** - Code coverage
- **FactoryBot** - Test data generation

---

## Best Practices

### YAGNI (You Ain't Gonna Need It)
Don't create directories or files until you need them. Rails generators will create them automatically:

```bash
# This creates spec/models/ and spec/factories/ automatically
rails g model User email:string

# This creates spec/requests/ automatically
rails g rspec:request api/v1/users
```

See [Rails Commands](reference/rails-commands.md) for more examples.

### Trunk-Based Development
Merge to main frequently using feature flags:

```ruby
# Deploy code to main, hide behind flag
if Flipper.enabled?(:new_feature, current_user)
  # New feature code
end

# Gradual rollout: 10% → 50% → 100%
Flipper.enable_percentage_of_actors(:new_feature, 10)
```

See [Flipper Guide](tools/flipper.md) for complete workflow.

### API Serialization
Use Blueprinter for consistent, fast JSON responses:

```ruby
class MessageBlueprint < ApplicationBlueprint
  identifier :id
  fields :content, :created_at

  association :sender, blueprint: UserBlueprint, view: :public
end

# Controller
render json: MessageBlueprint.render(messages)
```

See [Blueprint Guide](tools/blueprint.md) for advanced usage.

### Testing
- Maintain 90%+ code coverage
- Use FactoryBot for test data
- Use transactional fixtures (no DatabaseCleaner)

```bash
# Run tests with coverage
COVERAGE=true bundle exec rspec

# Coverage report in coverage/index.html
```

---

## Contributing to Documentation

Found an error or want to improve the docs?

1. Documentation files are in Markdown format
2. Follow the same structure and style as existing docs
3. Update this index (docs/README.md) if adding new documents
4. Submit a pull request following [Contributing Guide](../CONTRIBUTING.md)

### Documentation Style Guide
- Use clear, concise language
- Include code examples
- Provide real-world Chat API use cases
- Add tables of contents for long documents
- Use proper Markdown formatting
- Test all code examples

---

## Additional Resources

### External Documentation
- [Ruby on Rails Guides](https://guides.rubyonrails.org/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Redis Documentation](https://redis.io/documentation)
- [RSpec Documentation](https://rspec.info/documentation/)

### Community
- [GitHub Issues](https://github.com/yourusername/chat-api/issues)
- [GitHub Discussions](https://github.com/yourusername/chat-api/discussions)

---

**Need help?** Check the relevant guide above, or open an issue on GitHub!
