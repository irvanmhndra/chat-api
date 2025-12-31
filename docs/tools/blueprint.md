# Blueprint Serialization Guide for Chat API

Complete guide to using Blueprinter for data serialization in Chat API.

---

## Why Blueprint?

✅ **7-10x faster** than Jbuilder/AMS
✅ **API-first design** - not view-based
✅ **Clean DSL** - easy to read & maintain
✅ **Reusable** - DRY principle
✅ **Testable** - easy to unit test

---

## Basic Usage

### 1. Simple Blueprint

```ruby
# app/blueprints/user_blueprint.rb
class UserBlueprint < ApplicationBlueprint
  identifier :id

  fields :username, :display_name, :email, :bio

  field :avatar_url do |user|
    user.avatar.attached? ? url_for(user.avatar) : nil
  end

  field :created_at, datetime: true
end
```

**Controller:**
```ruby
class Api::V1::UsersController < BaseController
  def show
    user = User.find(params[:id])

    render json: UserBlueprint.render(user)
  end
end
```

**Response:**
```json
{
  "id": 1,
  "username": "john_doe",
  "display_name": "John Doe",
  "email": "john@example.com",
  "bio": "Hello world!",
  "avatar_url": "https://...",
  "created_at": "2025-12-25T10:00:00Z"
}
```

---

## Views - Multiple Representations

Blueprint memungkinkan multiple "views" dari data yang sama:

```ruby
# app/blueprints/user_blueprint.rb
class UserBlueprint < ApplicationBlueprint
  identifier :id

  # Default fields (always included)
  fields :username, :display_name

  # :public view (minimal info untuk public)
  view :public do
    fields :bio, :avatar_url
  end

  # :profile view (untuk profile page)
  view :profile do
    fields :bio, :avatar_url, :email
    field :last_seen_at, datetime: true
    field :online_status
  end

  # :detailed view (complete info)
  view :detailed do
    include_view :profile
    fields :created_at, :updated_at

    field :total_messages do |user|
      user.messages.count
    end

    field :total_conversations do |user|
      user.conversations.count
    end
  end
end
```

**Usage:**
```ruby
# Default view
UserBlueprint.render(user)

# Public view
UserBlueprint.render(user, view: :public)

# Profile view
UserBlueprint.render(user, view: :profile)

# Detailed view
UserBlueprint.render(user, view: :detailed)
```

---

## Associations - Nested Data

### One-to-One / Belongs To

```ruby
# app/blueprints/message_blueprint.rb
class MessageBlueprint < ApplicationBlueprint
  identifier :id

  fields :content, :message_type
  field :created_at, datetime: true

  # Nested user (sender)
  association :sender, blueprint: UserBlueprint, view: :public do
    # Rename 'sender' to 'user' in JSON
  end

  # Or dengan custom name
  association :sender, name: :user, blueprint: UserBlueprint, view: :public
end
```

**Response:**
```json
{
  "id": 123,
  "content": "Hello!",
  "message_type": "text",
  "created_at": "2025-12-25T10:00:00Z",
  "user": {
    "id": 1,
    "username": "john_doe",
    "display_name": "John Doe",
    "bio": "Hello world!",
    "avatar_url": "https://..."
  }
}
```

### One-to-Many / Has Many

```ruby
# app/blueprints/conversation_blueprint.rb
class ConversationBlueprint < ApplicationBlueprint
  identifier :id

  fields :name, :description, :type

  # Multiple participants
  association :participants, blueprint: ParticipantBlueprint

  # Atau dengan view
  view :detailed do
    association :messages, blueprint: MessageBlueprint do
      # Limit ke 50 messages terakhir
    end
  end
end
```

---

## Real-world Examples untuk Chat API

### 1. Message Blueprint (Complete)

```ruby
# app/blueprints/message_blueprint.rb
class MessageBlueprint < ApplicationBlueprint
  identifier :id

  fields :content, :message_type
  field :created_at, datetime: true
  field :updated_at, datetime: true

  # Sender info
  association :sender, name: :user, blueprint: UserBlueprint, view: :public

  # Edited status
  field :edited do |message|
    message.edited_at.present?
  end

  field :edited_at, datetime: true, if: ->(message, _) { message.edited_at.present? }

  # Reply info (jika message adalah reply)
  field :reply_to do |message|
    if message.reply_to_id.present?
      MessageBlueprint.render_as_hash(message.reply_to, view: :minimal)
    end
  end

  # Metadata
  field :metadata

  # Minimal view (untuk nested/preview)
  view :minimal do
    fields :id, :content
    association :sender, name: :user, blueprint: UserBlueprint do
      fields :id, :username
    end
  end

  # Detailed view (dengan reactions & read receipts)
  view :detailed do
    association :reactions, blueprint: ReactionBlueprint

    field :read_by_count do |message|
      message.read_receipts.count
    end

    field :read_by, if: ->(_, options) { options[:include_read_receipts] } do |message|
      ReadReceiptBlueprint.render_as_hash(message.read_receipts)
    end
  end
end
```

### 2. Conversation Blueprint

```ruby
# app/blueprints/conversation_blueprint.rb
class ConversationBlueprint < ApplicationBlueprint
  identifier :id

  fields :name, :description, :type
  field :avatar_url
  field :created_at, datetime: true
  field :last_message_at, datetime: true

  # Creator
  association :creator, blueprint: UserBlueprint, view: :public

  # Participant count
  field :participant_count do |conversation|
    conversation.participants.count
  end

  # Last message preview
  field :last_message do |conversation|
    if conversation.messages.any?
      MessageBlueprint.render_as_hash(
        conversation.messages.last,
        view: :minimal
      )
    end
  end

  # Unread count (requires current_user from options)
  field :unread_count, if: ->(_, options) { options[:current_user].present? } do |conversation, options|
    participant = conversation.participants.find_by(user: options[:current_user])
    return 0 unless participant

    conversation.messages
      .where('created_at > ?', participant.last_read_at || Time.at(0))
      .count
  end

  # List view (untuk conversation list)
  view :list do
    fields :id, :name, :type, :last_message_at
    field :last_message
    field :unread_count
    field :participant_count
  end

  # Detailed view (untuk conversation page)
  view :detailed do
    association :participants, blueprint: ParticipantBlueprint
    field :settings
  end
end
```

### 3. Participant Blueprint

```ruby
# app/blueprints/participant_blueprint.rb
class ParticipantBlueprint < ApplicationBlueprint
  identifier :id

  association :user, blueprint: UserBlueprint, view: :public

  fields :role, :joined_at
  field :last_read_at, datetime: true

  # Admin permissions
  field :is_admin do |participant|
    %w[owner admin].include?(participant.role)
  end

  field :is_owner do |participant|
    participant.role == 'owner'
  end
end
```

### 4. Reaction Blueprint

```ruby
# app/blueprints/reaction_blueprint.rb
class ReactionBlueprint < ApplicationBlueprint
  identifier :id

  fields :emoji
  field :created_at, datetime: true

  association :user, blueprint: UserBlueprint do
    fields :id, :username
  end
end
```

---

## Pagination dengan Blueprint

### Using Pagy

```ruby
# Controller
class Api::V1::MessagesController < BaseController
  def index
    conversation = Conversation.find(params[:conversation_id])

    @pagy, messages = pagy(
      conversation.messages.includes(:sender).order(created_at: :desc),
      items: 50
    )

    render json: {
      messages: MessageBlueprint.render_as_hash(messages),
      pagination: pagy_metadata(@pagy)
    }
  end
end
```

### Cursor-based Pagination

```ruby
# Controller
class Api::V1::MessagesController < BaseController
  def index
    conversation = Conversation.find(params[:conversation_id])

    messages = conversation.messages.includes(:sender)

    # Cursor pagination
    if params[:before_id].present?
      messages = messages.where('id < ?', params[:before_id])
    elsif params[:after_id].present?
      messages = messages.where('id > ?', params[:after_id])
    end

    messages = messages.order(id: :desc).limit(50)

    render json: {
      messages: MessageBlueprint.render_as_hash(messages),
      has_more: messages.count == 50,
      cursors: {
        before: messages.last&.id,
        after: messages.first&.id
      }
    }
  end
end
```

---

## Collections vs Single Objects

```ruby
# Single object
user = User.find(1)
UserBlueprint.render(user)                    # Returns JSON string
UserBlueprint.render_as_hash(user)           # Returns Hash
UserBlueprint.render_as_json(user)           # Returns JSON string (alias)

# Collection
users = User.all
UserBlueprint.render(users)                   # Returns JSON array
UserBlueprint.render_as_hash(users)          # Returns Array of Hashes
```

---

## Conditional Fields

### Using `if` option

```ruby
class UserBlueprint < ApplicationBlueprint
  identifier :id

  fields :username, :display_name

  # Only show email to authenticated user
  field :email, if: ->(user, options) { options[:current_user]&.id == user.id }

  # Only show if present
  field :bio, if: ->(user, _) { user.bio.present? }
end
```

**Usage:**
```ruby
# Without current_user (email hidden)
UserBlueprint.render(user)

# With current_user (email shown if it's their own profile)
UserBlueprint.render(user, current_user: current_user)
```

### Using `unless` option

```ruby
class MessageBlueprint < ApplicationBlueprint
  identifier :id

  # Don't show content if deleted
  field :content, unless: ->(message, _) { message.deleted_at.present? }

  # Show deleted indicator
  field :deleted, unless: ->(message, _) { message.deleted_at.nil? } do
    true
  end
end
```

---

## Transform/Format Fields

### Custom Transformations

```ruby
class UserBlueprint < ApplicationBlueprint
  identifier :id

  # Transform username to lowercase
  field :username do |user|
    user.username.downcase
  end

  # Format datetime
  field :joined_date do |user|
    user.created_at.strftime('%B %d, %Y')
  end

  # Computed field
  field :full_info do |user|
    "#{user.display_name} (@#{user.username})"
  end
end
```

---

## Passing Options

Options berguna untuk passing context (current_user, permissions, dll):

```ruby
# Controller
class Api::V1::ConversationsController < BaseController
  def index
    conversations = current_user.conversations

    render json: ConversationBlueprint.render(
      conversations,
      view: :list,
      current_user: current_user,
      include_unread: true
    )
  end
end

# Blueprint
class ConversationBlueprint < ApplicationBlueprint
  field :unread_count, if: ->(_, opts) { opts[:include_unread] } do |conv, opts|
    # Use opts[:current_user]
    calculate_unread(conv, opts[:current_user])
  end
end
```

---

## Performance Tips

### 1. Eager Loading (N+1 Prevention)

```ruby
# ❌ Bad - N+1 queries
messages = Message.all
MessageBlueprint.render(messages)  # Will trigger N queries for senders!

# ✅ Good - Eager load
messages = Message.includes(:sender, :reactions).all
MessageBlueprint.render(messages)  # Only 3 queries total
```

### 2. Use `render_as_hash` untuk nested blueprints

```ruby
# Faster untuk nested data
field :last_message do |conversation|
  MessageBlueprint.render_as_hash(conversation.messages.last)
end
```

### 3. Limit associations

```ruby
# Don't load all messages
view :preview do
  field :recent_messages do |conversation|
    MessageBlueprint.render_as_hash(
      conversation.messages.limit(10)
    )
  end
end
```

---

## Testing Blueprints

```ruby
# spec/blueprints/user_blueprint_spec.rb
require 'rails_helper'

RSpec.describe UserBlueprint do
  let(:user) { create(:user, username: 'john_doe', email: 'john@example.com') }

  describe 'default view' do
    subject { described_class.render_as_hash(user) }

    it 'includes id' do
      expect(subject[:id]).to eq(user.id)
    end

    it 'includes username' do
      expect(subject[:username]).to eq('john_doe')
    end

    it 'includes email' do
      expect(subject[:email]).to eq('john@example.com')
    end
  end

  describe 'public view' do
    subject { described_class.render_as_hash(user, view: :public) }

    it 'does not include email' do
      expect(subject).not_to have_key(:email)
    end
  end
end
```

---

## Advanced: Custom Serializers

Untuk kasus yang sangat spesifik:

```ruby
class CustomMessageSerializer
  def self.render(messages, options = {})
    messages.map do |message|
      {
        id: message.id,
        text: message.content,
        user: {
          id: message.sender.id,
          name: message.sender.username
        },
        timestamp: message.created_at.to_i,
        # Custom format untuk frontend tertentu
        reactions: group_reactions(message.reactions)
      }
    end
  end

  private

  def self.group_reactions(reactions)
    reactions.group_by(&:emoji).transform_values do |reacts|
      {
        count: reacts.count,
        users: reacts.map { |r| r.user.username }
      }
    end
  end
end
```

---

## Summary - Best Practices

1. ✅ **Use views** untuk different representations
2. ✅ **Eager load** associations untuk avoid N+1
3. ✅ **Use `render_as_hash`** untuk nested blueprints
4. ✅ **Pass options** untuk context (current_user, etc.)
5. ✅ **Conditional fields** dengan `if`/`unless`
6. ✅ **Keep blueprints simple** - complex logic di service objects
7. ✅ **Test your blueprints**
8. ✅ **Reuse blueprints** - DRY principle

---

## Resources

- Blueprint GitHub: https://github.com/procore/blueprinter
- Blueprint Docs: https://github.com/procore/blueprinter#usage
- Oj (JSON parser): https://github.com/ohler55/oj

---

**Happy Serializing! 🚀**
