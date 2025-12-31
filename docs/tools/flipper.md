# Flipper Feature Flags Guide for Chat API

Complete guide to using Flipper for Trunk-Based Development in Chat API.

---

## Why Feature Flags?

✅ **Trunk-Based Development** - Merge to main daily, hide incomplete features
✅ **Progressive Rollouts** - 10% → 50% → 100% users
✅ **Kill Switches** - Disable buggy features instantly without deploy
✅ **A/B Testing** - Test different implementations
✅ **Dark Launches** - Deploy & test in production safely

---

## Basic Concepts

### **Feature Flag States:**

```ruby
# Boolean (on/off for everyone)
Flipper.enable(:new_feature)
Flipper.disable(:new_feature)

# Per Actor (specific user/entity)
Flipper.enable_actor(:premium_features, current_user)

# Percentage of Actors (% of users)
Flipper.enable_percentage_of_actors(:beta_ui, 25)  # 25% of users

# Percentage of Time (% of requests)
Flipper.enable_percentage_of_time(:new_algorithm, 10)  # 10% of requests

# Group (predefined groups)
Flipper.enable_group(:admin_panel, :admins)
```

---

## Setup Flipper (Already done in [Setup Guide](../../SETUP_GUIDE.md))

```bash
# Generate migration
rails g flipper:active_record
rails db:migrate

# Configure in config/initializers/flipper.rb
```

---

## Usage Patterns untuk Chat API

### **1. Progressive Feature Rollout**

**Scenario:** Deploying new Channels feature

```ruby
# Step 1: Deploy code with feature flag (disabled)
class Api::V1::ConversationsController < BaseController
  def index
    conversations = current_user.conversations

    # Filter channels if feature not enabled
    unless Flipper.enabled?(:channels, current_user)
      conversations = conversations.where.not(type: 'Channel')
    end

    render json: ConversationBlueprint.render(conversations)
  end

  def create
    # Prevent channel creation if feature disabled
    if params[:type] == 'Channel' && !Flipper.enabled?(:channels, current_user)
      return render_error('Channels not available yet', status: :forbidden)
    end

    conversation = Conversation.create!(conversation_params)
    render json: ConversationBlueprint.render(conversation)
  end
end
```

**Rollout Strategy:**
```ruby
# Day 1: Enable for internal team only
admin_users = User.where(admin: true)
admin_users.each { |user| Flipper.enable_actor(:channels, user) }

# Day 3: Enable for 5% of users (beta testers)
Flipper.enable_percentage_of_actors(:channels, 5)

# Day 7: Monitor metrics, increase to 25%
Flipper.enable_percentage_of_actors(:channels, 25)

# Day 10: 50%
Flipper.enable_percentage_of_actors(:channels, 50)

# Day 14: Full launch!
Flipper.enable(:channels)

# Later: Remove flag from code
# (just use channels directly, no more if/else)
```

---

### **2. Kill Switch (Emergency Disable)**

**Scenario:** CPU-intensive message translation feature

```ruby
# app/services/message_service.rb
class MessageService
  def self.create_message(params, user)
    message = Message.create!(params.merge(sender: user))

    # Translation feature (expensive!)
    if Flipper.enabled?(:auto_translate_messages)
      begin
        translated = TranslationService.translate(message.content)
        message.update(translations: translated)
      rescue StandardError => e
        # Log error but don't fail message creation
        Rails.logger.error("Translation failed: #{e.message}")
      end
    end

    # Broadcast via ActionCable
    broadcast_message(message)

    message
  end
end
```

**Emergency Disable:**
```ruby
# Production issue: Translation API down, causing timeouts
# Disable instantly (no deploy needed!)
Flipper.disable(:auto_translate_messages)

# Users can still send messages, just no auto-translation
# Fix the issue, then re-enable
Flipper.enable(:auto_translate_messages)
```

---

### **3. A/B Testing**

**Scenario:** Testing two notification strategies

```ruby
# app/jobs/notification_job.rb
class NotificationJob < ApplicationJob
  def perform(message_id)
    message = Message.find(message_id)
    recipients = message.conversation.participants.where.not(user_id: message.sender_id)

    recipients.each do |participant|
      if Flipper.enabled?(:instant_notifications, participant.user)
        # Strategy A: Instant push notification
        send_instant_push(participant.user, message)
      else
        # Strategy B: Batched notifications (every 5 minutes)
        queue_batched_notification(participant.user, message)
      end
    end
  end
end
```

**A/B Test Setup:**
```ruby
# Enable instant notifications for 50% of users
Flipper.enable_percentage_of_actors(:instant_notifications, 50)

# Monitor metrics:
# - User engagement
# - Notification click-through rate
# - Battery usage complaints
# - Server load

# After 2 weeks, choose winner based on data
# Winner: Instant notifications
Flipper.enable(:instant_notifications)

# Remove batched notification code
```

---

### **4. Premium Features (Tiered Access)**

**Scenario:** Unlimited file uploads for premium users

```ruby
# app/models/user.rb
class User < ApplicationRecord
  def premium?
    subscription_tier == 'premium'
  end

  def can_upload_file?(file_size)
    if Flipper.enabled?(:unlimited_uploads, self)
      true  # Premium users: no limit
    else
      # Free users: 10MB limit
      file_size <= 10.megabytes
    end
  end
end

# Enable feature
Flipper.register(:premium_users) do |actor|
  actor.respond_to?(:premium?) && actor.premium?
end

# In initializer or during user premium upgrade
premium_users = User.where(subscription_tier: 'premium')
premium_users.each { |user| Flipper.enable_actor(:unlimited_uploads, user) }

# Or use group
Flipper.enable_group(:unlimited_uploads, :premium_users)
```

**Controller:**
```ruby
# app/controllers/api/v1/media_controller.rb
class Api::V1::MediaController < BaseController
  def upload
    file = params[:file]

    unless current_user.can_upload_file?(file.size)
      return render_error(
        'File too large. Upgrade to premium for unlimited uploads.',
        status: :payment_required
      )
    end

    attachment = ActiveStorage::Blob.create_and_upload!(
      io: file.open,
      filename: file.original_filename
    )

    render json: { id: attachment.id, url: url_for(attachment) }
  end
end
```

---

### **5. Dark Launch / Testing in Production**

**Scenario:** New Elasticsearch-based search (test without affecting users)

```ruby
# app/controllers/api/v1/search_controller.rb
class Api::V1::SearchController < BaseController
  def messages
    query = params[:q]

    # Production search (PostgreSQL full-text)
    results = search_with_postgresql(query)

    # Dark launch: Also run new search (but don't use results yet)
    if Flipper.enabled?(:elasticsearch_search)
      begin
        # Run new search in background, compare results
        CompareSearchResultsJob.perform_later(
          query: query,
          pg_results: results.pluck(:id),
          user_id: current_user.id
        )
      rescue StandardError => e
        # Log error, but don't affect user
        Rails.logger.error("Elasticsearch test failed: #{e.message}")
      end
    end

    render json: MessageBlueprint.render(results)
  end
end
```

**Dark Launch Strategy:**
```ruby
# Enable for admins only (they see Elasticsearch results)
admins.each { |admin| Flipper.enable_actor(:elasticsearch_search, admin) }

# Collect metrics:
# - Search speed comparison
# - Result quality comparison
# - Error rates

# When confident, switch everyone to new search
Flipper.enable(:elasticsearch_search)
```

---

### **6. Gradual Code Migration**

**Scenario:** Migrating from old to new reaction system

```ruby
# app/models/message.rb
class Message < ApplicationRecord
  def add_reaction(user, emoji)
    if Flipper.enabled?(:new_reaction_system)
      # New system: Normalized reaction table
      reactions.create!(user: user, emoji: emoji)
    else
      # Old system: JSONB column
      self.reaction_data ||= {}
      self.reaction_data[emoji] ||= []
      self.reaction_data[emoji] << user.id
      save!
    end
  end

  def get_reactions
    if Flipper.enabled?(:new_reaction_system)
      # New system
      reactions.group(:emoji).count
    else
      # Old system
      reaction_data || {}
    end
  end
end
```

**Migration Strategy:**
```ruby
# Step 1: Deploy dual-write code (writes to both systems)
# Step 2: Backfill old data to new system
# Step 3: Enable new system for 10% of users (reads from new system)
Flipper.enable_percentage_of_actors(:new_reaction_system, 10)
# Step 4: Monitor, gradually increase
# Step 5: 100% enabled
Flipper.enable(:new_reaction_system)
# Step 6: Remove old code & JSONB column
```

---

## Flipper Groups

Define groups for easier management:

```ruby
# config/initializers/flipper.rb
Flipper.register(:admins) do |actor|
  actor.respond_to?(:admin?) && actor.admin?
end

Flipper.register(:beta_testers) do |actor|
  actor.respond_to?(:beta_tester?) && actor.beta_tester?
end

Flipper.register(:premium_users) do |actor|
  actor.respond_to?(:premium?) && actor.premium?
end

Flipper.register(:internal_team) do |actor|
  actor.respond_to?(:email) && actor.email.end_with?('@yourcompany.com')
end
```

**Usage:**
```ruby
# Enable for group
Flipper.enable_group(:experimental_features, :beta_testers)

# Check
Flipper.enabled?(:experimental_features, current_user)
```

---

## Flipper UI

Access web dashboard: `http://localhost:3000/flipper`

**Features:**
- View all flags
- Enable/disable with clicks
- See who has access
- Percentage controls
- Search flags

**Production Security:**
```ruby
# config/routes.rb
Rails.application.routes.draw do
  # Protect with authentication
  authenticate :user, ->(user) { user.admin? } do
    mount Flipper::UI.app(Flipper) => '/admin/flipper'
  end
end
```

---

## Best Practices

### **1. Naming Conventions**
```ruby
# Good names (descriptive + date)
:channels_2025_12
:new_search_algorithm_2025_q1
:premium_file_uploads

# Bad names (vague)
:new_feature
:test
:experimental
```

### **2. Flag Lifecycle**
```ruby
# Creation
Flipper.enable(:new_feature)  # Deploy with flag

# Testing
Flipper.enable_actor(:new_feature, beta_users)  # Test with subset

# Rollout
Flipper.enable_percentage_of_actors(:new_feature, 10)  # 10%
Flipper.enable_percentage_of_actors(:new_feature, 50)  # 50%
Flipper.enable(:new_feature)  # 100%

# Removal (30-90 days after 100%)
# Remove flag from code, just use new code directly
```

### **3. Flag Cleanup**
```ruby
# Check flag age
Flipper.features.each do |feature|
  created_at = feature.created_at  # If you track this
  if created_at < 90.days.ago && feature.enabled?
    puts "Consider removing flag: #{feature.name}"
  end
end

# Delete flag
Flipper.remove(:old_feature)
```

### **4. Testing with Flags**
```ruby
# spec/requests/api/v1/messages_spec.rb
RSpec.describe "Messages API" do
  describe "POST /api/v1/messages" do
    context "with auto_translate enabled" do
      before { Flipper.enable(:auto_translate_messages) }
      after { Flipper.disable(:auto_translate_messages) }

      it "translates message" do
        post "/api/v1/messages", params: { content: "Hello" }
        expect(response_json['translations']).to be_present
      end
    end

    context "with auto_translate disabled" do
      before { Flipper.disable(:auto_translate_messages) }

      it "does not translate message" do
        post "/api/v1/messages", params: { content: "Hello" }
        expect(response_json['translations']).to be_nil
      end
    end
  end
end
```

---

## Common Patterns

### **Pattern 1: Fallback to Stable**
```ruby
def process_message(message)
  if Flipper.enabled?(:new_processing)
    begin
      new_message_processor.process(message)
    rescue StandardError => e
      # Fallback to stable version
      Rails.logger.error("New processor failed: #{e}")
      old_message_processor.process(message)
    end
  else
    old_message_processor.process(message)
  end
end
```

### **Pattern 2: Metrics Collection**
```ruby
def search(query)
  if Flipper.enabled?(:new_search)
    start_time = Time.current
    results = new_search_engine.search(query)
    duration = Time.current - start_time

    # Log metrics
    Rails.logger.info("New search: #{duration}ms, #{results.count} results")

    results
  else
    old_search(query)
  end
end
```

### **Pattern 3: Graceful Degradation**
```ruby
def get_recommendations(user)
  if Flipper.enabled?(:ml_recommendations, user)
    # ML-based (might be slow/fail)
    begin
      Timeout.timeout(2) do
        MLService.get_recommendations(user)
      end
    rescue StandardError
      # Fallback to simple recommendations
      simple_recommendations(user)
    end
  else
    simple_recommendations(user)
  end
end
```

---

## Monitoring & Alerts

```ruby
# Check flag status in monitoring
Flipper.features.each do |feature|
  if feature.enabled?
    enabled_for = Flipper.feature(feature.name).actors_value.count
    StatsD.gauge("flipper.#{feature.name}.actors", enabled_for)
  end
end

# Alert on unexpected changes
# (someone accidentally disabled important feature)
if Flipper.disabled?(:critical_feature) && Rails.env.production?
  Rollbar.critical("Critical feature flag disabled!")
end
```

---

## Summary - TBD Workflow

```ruby
# Day 1: Start feature
git checkout main
# ... implement channels feature with flag ...
Flipper.disable(:channels)  # Default: disabled
git commit -m "Add channels (behind feature flag)"
git push origin main  # ✅ Safe to deploy!

# Day 2-10: Continue development
# ... commit to main daily ...
# Feature hidden behind flag, users don't see it

# Day 11: Feature complete, enable for team
Flipper.enable_actor(:channels, team_members)

# Day 12: Beta test
Flipper.enable_percentage_of_actors(:channels, 5)

# Day 14: Rollout
Flipper.enable_percentage_of_actors(:channels, 25)
Flipper.enable_percentage_of_actors(:channels, 100)

# Day 45: Remove flag (after stable)
# Delete flag code, use channels directly
```

---

## Resources

- Flipper Docs: https://www.flippercloud.io/docs
- Flipper GitHub: https://github.com/flippercloud/flipper
- Feature Flag Best Practices: https://martinfowler.com/articles/feature-toggles.html

---

**Happy Feature Flagging! 🚩**
