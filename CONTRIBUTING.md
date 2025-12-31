# Contributing to Chat API

Thank you for your interest in contributing to Chat API! This document provides guidelines and instructions for contributing to the project.

## Code of Conduct

By participating in this project, you agree to maintain a respectful and collaborative environment. We expect all contributors to:

- Use welcoming and inclusive language
- Be respectful of differing viewpoints and experiences
- Gracefully accept constructive criticism
- Focus on what is best for the community
- Show empathy towards other community members

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check the existing issues to avoid duplicates. When creating a bug report, include:

- **Clear title and description**
- **Steps to reproduce** the behavior
- **Expected behavior** vs actual behavior
- **Screenshots** if applicable
- **Environment details**: Ruby version, Rails version, OS, etc.
- **Additional context**: error messages, logs, etc.

**Example bug report:**

```markdown
## Bug: Message reactions not updating in real-time

**Steps to reproduce:**
1. Open conversation in two different browser windows
2. Add a reaction to a message in window 1
3. Observe window 2 does not update

**Expected:** Reaction appears in both windows immediately
**Actual:** Reaction only appears after page refresh

**Environment:**
- Ruby 3.3.0
- Rails 8.1.1
- macOS 15.2
- Chrome 120

**Error logs:**
ActionCable connection failed: ...
```

### Suggesting Features

Feature suggestions are welcome! Please provide:

- **Clear use case**: What problem does this solve?
- **Proposed solution**: How would this feature work?
- **Alternatives considered**: What other approaches did you think about?
- **Additional context**: Examples, mockups, references

### Pull Requests

We actively welcome pull requests! Here's the workflow:

1. **Fork the repository** and create your branch from `main`
2. **Follow the development workflow** (see below)
3. **Write clear commit messages** (see commit message guidelines)
4. **Ensure tests pass** and add new tests for your changes
5. **Update documentation** if needed
6. **Submit a pull request** with a clear description

## Development Workflow

### 1. Setup Development Environment

```bash
# Fork and clone the repository
git clone https://github.com/yourusername/chat-api.git
cd chat-api

# Install dependencies
bundle install

# Setup database
rails db:create db:migrate db:seed

# Run tests to ensure everything works
bundle exec rspec
```

### 2. Create a Feature Branch

Use descriptive branch names:

```bash
# Feature branch
git checkout -b feature/add-message-reactions

# Bug fix branch
git checkout -b fix/reaction-broadcast-issue

# Documentation update
git checkout -b docs/update-api-endpoints
```

### 3. Make Your Changes

#### Code Style

- Follow [Ruby Style Guide](https://rubystyle.guide/)
- Follow [Rails Style Guide](https://rails.rubygems.org/rubystyle.html)
- Run RuboCop before committing: `bundle exec rubocop`
- Use meaningful variable and method names
- Keep methods small and focused (max 10-15 lines)
- Add comments for complex logic

#### Testing Requirements

All code changes must include tests:

```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/models/message_spec.rb

# Run with coverage (must maintain 90%+ coverage)
COVERAGE=true bundle exec rspec
```

**Test coverage requirements:**
- Models: 100% coverage
- Controllers/Requests: 90%+ coverage
- Services: 95%+ coverage
- Overall: 90%+ coverage

#### Feature Flags

New features should be developed behind feature flags:

```ruby
# Enable feature for gradual rollout
class MessagesController < ApplicationController
  def create
    if Flipper.enabled?(:message_translations, current_user)
      # New translation feature
      TranslationService.translate(message)
    end

    # Existing functionality
  end
end
```

See [Flipper Guide](docs/tools/flipper.md) for trunk-based development workflow.

#### Database Migrations

- Use reversible migrations when possible
- Add indexes for foreign keys and frequently queried columns
- Use `change` method instead of `up`/`down` when possible
- Test rollback: `rails db:migrate && rails db:rollback && rails db:migrate`

```ruby
class AddIndexToMessages < ActiveRecord::Migration[8.0]
  def change
    add_index :messages, :conversation_id
    add_index :messages, [:conversation_id, :created_at]
  end
end
```

### 4. Commit Your Changes

#### Commit Message Guidelines

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```bash
# Format: <type>(<scope>): <subject>

# Types:
feat:     New feature
fix:      Bug fix
docs:     Documentation changes
style:    Code style changes (formatting, no logic change)
refactor: Code refactoring
test:     Adding or updating tests
chore:    Maintenance tasks

# Examples:
git commit -m "feat(messages): add message translation support"
git commit -m "fix(reactions): resolve real-time broadcast issue"
git commit -m "docs(api): update authentication endpoints"
git commit -m "test(messages): add tests for message editing"
```

**Good commit messages:**
- `feat(channels): add typing indicators to channels`
- `fix(auth): resolve JWT token expiration issue`
- `refactor(services): extract message creation logic to service object`

**Bad commit messages:**
- `fixed stuff`
- `WIP`
- `updates`

### 5. Push and Create Pull Request

```bash
# Push to your fork
git push origin feature/add-message-reactions

# Create pull request on GitHub
```

#### Pull Request Guidelines

Your PR description should include:

1. **Summary**: What does this PR do?
2. **Motivation**: Why is this change needed?
3. **Implementation**: How did you implement it?
4. **Testing**: What tests did you add?
5. **Screenshots**: If UI-related (for admin panel)
6. **Breaking changes**: Any backward incompatible changes?

**PR template example:**

```markdown
## Summary
Adds message translation support using Google Translate API

## Motivation
Users requested ability to translate messages to their preferred language

## Implementation
- Added TranslationService using google-cloud-translate gem
- Added `translations` JSONB column to messages table
- Implemented feature flag for gradual rollout
- Added background job for async translation

## Testing
- Unit tests for TranslationService
- Request specs for translation endpoint
- Feature flag tests
- Coverage: 95%

## Screenshots
N/A (API-only)

## Breaking Changes
None

## Checklist
- [x] Tests added and passing
- [x] Documentation updated
- [x] Feature flag implemented
- [x] RuboCop passing
- [x] Database migration tested (up and down)
```

### 6. Code Review Process

- Reviewers will provide feedback on your PR
- Address feedback by pushing new commits to your branch
- Once approved, a maintainer will merge your PR
- Your branch will be deleted after merge

## Development Best Practices

### Use Rails Generators

Minimize manual file creation:

```bash
# Generate model with tests
rails g model Message conversation:references content:text

# Generate request spec
rails g rspec:request api/v1/messages

# Generate service object
rails g service MessageService
```

See [Rails Commands](docs/reference/rails-commands.md) for comprehensive examples.

### Follow YAGNI Principle

**You Ain't Gonna Need It** - Don't build features or abstractions you don't currently need.

**Good:**
```ruby
# Simple, direct implementation
def create
  @message = Message.create!(message_params)
  render json: MessageBlueprint.render(@message)
end
```

**Bad:**
```ruby
# Over-engineered with unnecessary abstractions
def create
  @message = MessageFactory.build_from_params(message_params)
  @message = MessagePersistenceStrategy.save(@message)
  @presenter = MessagePresenterFactory.create(@message)
  render json: @presenter.to_json
end
```

### API Serialization

Use Blueprinter for fast, consistent JSON serialization:

```ruby
# app/blueprints/message_blueprint.rb
class MessageBlueprint < ApplicationBlueprint
  identifier :id
  fields :content, :message_type

  association :sender, blueprint: UserBlueprint, view: :public

  view :detailed do
    association :reactions, blueprint: ReactionBlueprint
  end
end

# Controller
render json: MessageBlueprint.render(messages, view: :detailed)
```

See [Blueprint Guide](docs/tools/blueprint.md) for detailed examples.

### Background Jobs

Use Sidekiq for async operations:

```ruby
# app/jobs/notification_job.rb
class NotificationJob < ApplicationJob
  queue_as :default

  def perform(message_id)
    message = Message.find(message_id)
    NotificationService.send_push_notification(message)
  end
end

# Usage
NotificationJob.perform_later(message.id)
```

### Security Best Practices

1. **Always use strong parameters**
   ```ruby
   def message_params
     params.require(:message).permit(:content, :message_type)
   end
   ```

2. **Implement authorization with Pundit**
   ```ruby
   def update
     @message = Message.find(params[:id])
     authorize @message  # Uses Pundit policy
     @message.update!(message_params)
   end
   ```

3. **Validate file uploads**
   ```ruby
   validates :avatar,
     content_type: ['image/png', 'image/jpg'],
     size: { less_than: 5.megabytes }
   ```

4. **Sanitize user input** (Rails does this by default, don't bypass it)

## Testing Guidelines

### Test Structure

```ruby
# spec/models/message_spec.rb
RSpec.describe Message, type: :model do
  describe 'associations' do
    it { should belong_to(:conversation) }
    it { should belong_to(:sender) }
  end

  describe 'validations' do
    it { should validate_presence_of(:content) }
  end

  describe '#editable_by?' do
    let(:message) { create(:message) }
    let(:user) { message.sender }

    it 'returns true for message sender' do
      expect(message.editable_by?(user)).to be true
    end

    it 'returns false for other users' do
      other_user = create(:user)
      expect(message.editable_by?(other_user)).to be false
    end
  end
end
```

### Use Factories (FactoryBot)

```ruby
# spec/factories/messages.rb
FactoryBot.define do
  factory :message do
    association :conversation
    association :sender, factory: :user
    content { Faker::Lorem.sentence }
    message_type { 'text' }

    trait :with_reactions do
      after(:create) do |message|
        create_list(:reaction, 3, message: message)
      end
    end
  end
end

# Usage in tests
message = create(:message)
message_with_reactions = create(:message, :with_reactions)
```

### Request Specs

```ruby
# spec/requests/api/v1/messages_spec.rb
RSpec.describe 'Messages API', type: :request do
  let(:user) { create(:user) }
  let(:conversation) { create(:conversation) }
  let(:headers) { auth_headers(user) }  # Helper for JWT token

  describe 'POST /api/v1/conversations/:id/messages' do
    let(:params) { { message: { content: 'Hello' } } }

    it 'creates a new message' do
      expect {
        post "/api/v1/conversations/#{conversation.id}/messages",
             params: params,
             headers: headers
      }.to change(Message, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_response['content']).to eq('Hello')
    end
  end
end
```

## Documentation

When adding features, update relevant documentation:

- **API changes**: Update [Rswag specs](docs/tools/rswag.md) for OpenAPI docs
- **New tools/gems**: Add guide in `docs/tools/`
- **Architecture changes**: Update [overview](docs/architecture/overview.md)
- **Setup changes**: Update installation guide

## Release Process

Maintainers follow this process for releases:

1. Update `CHANGELOG.md` with release notes
2. Bump version in appropriate files
3. Create git tag: `git tag -a v1.2.0 -m "Release 1.2.0"`
4. Push tag: `git push origin v1.2.0`
5. Create GitHub release with changelog

## Getting Help

- **Documentation**: Check [docs/](docs/) directory
- **Issues**: Search existing [issues](https://github.com/yourusername/chat-api/issues)
- **Discussions**: Ask in [GitHub Discussions](https://github.com/yourusername/chat-api/discussions)
- **Discord**: Join our community server (if available)

## Recognition

Contributors will be recognized in:
- `CONTRIBUTORS.md` file
- Release notes for their contributions
- GitHub contributors page

Thank you for contributing to Chat API!
