# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Initial Setup
- Rails 8.1.1 API-only application setup
- PostgreSQL 15+ database configuration
- Redis integration for caching and ActionCable
- RSpec testing framework with SimpleCov
- FactoryBot for test data generation

### Tools & Libraries
- **Blueprinter**: Fast JSON serialization (7-10x faster than Jbuilder)
- **Flipper**: Feature flags for trunk-based development
- **ActiveAdmin**: Admin dashboard for moderation and customer support
- **Devise**: Authentication for admin users
- **JWT**: Token-based authentication for API users
- **Pundit**: Authorization policies
- **Sidekiq**: Background job processing
- **Rswag**: OpenAPI/Swagger API documentation
- **Pagy**: Lightweight pagination

### Database Schema
- Users table for API authentication
- AdminUsers table for admin panel access (Devise)
- Database configuration using Rails 8.1 `max_connections` (replaces `pool`)
- Unix domain socket for development (no password required)

### Documentation
- Comprehensive setup guide in `docs/getting-started/`
- Architecture documentation in `docs/architecture/`
- Tool-specific guides in `docs/tools/`:
  - Blueprint serialization guide
  - Flipper feature flags guide
  - ActiveAdmin admin panel guide
  - Rswag API documentation guide
- Rails generators reference in `docs/reference/`
- Industry-standard documentation structure

### Development Practices
- YAGNI approach for RSpec setup (directories created on-demand)
- Rails 8.1 conventions and best practices
- Transactional fixtures for testing (no DatabaseCleaner)
- Code coverage tracking with SimpleCov

---

## Release Template

Use this template for future releases:

```markdown
## [Version] - YYYY-MM-DD

### Added
- New features

### Changed
- Changes to existing functionality

### Deprecated
- Soon-to-be removed features

### Removed
- Removed features

### Fixed
- Bug fixes

### Security
- Security improvements
```

---

## Version History

### Legend
- **Added**: New features
- **Changed**: Changes to existing functionality
- **Deprecated**: Soon-to-be removed features
- **Removed**: Removed features
- **Fixed**: Bug fixes
- **Security**: Security improvements

---

_Note: This project is currently in initial development. Version 0.1.0 will be released when core messaging features are implemented._
