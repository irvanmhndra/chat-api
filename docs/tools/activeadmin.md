# ActiveAdmin Guide for Chat API

Complete guide to using ActiveAdmin for admin panel, moderation, and customer support.

---

## Access Admin Panel

```
URL: http://localhost:3000/admin
Login: admin@example.com / password123
```

---

## Common Admin Resources for Chat API

### **1. User Management**

```ruby
# app/admin/users.rb
ActiveAdmin.register User do
  menu priority: 1, label: "Users"

  permit_params :email, :username, :display_name, :bio, :online_status

  # Filters
  filter :email
  filter :username
  filter :online_status, as: :select, collection: ['online', 'offline', 'away']
  filter :created_at
  filter :last_seen_at

  # Index page (list view)
  index do
    selectable_column
    id_column
    column :username
    column :email
    column :display_name
    column :online_status do |user|
      status_tag user.online_status, class: user.online_status
    end
    column "Messages", :messages_count do |user|
      user.messages.count
    end
    column :last_seen_at
    column :created_at
    actions
  end

  # Show page (detail view)
  show do
    attributes_table do
      row :id
      row :username
      row :email
      row :display_name
      row :bio
      row :online_status
      row :last_seen_at
      row :created_at
      row :updated_at
      row "Avatar" do |user|
        if user.avatar.attached?
          image_tag url_for(user.avatar), size: "200x200"
        end
      end
    end

    panel "Recent Messages" do
      table_for user.messages.order(created_at: :desc).limit(10) do
        column "ID", :id
        column "Content" do |msg|
          truncate(msg.content, length: 100)
        end
        column "Conversation" do |msg|
          link_to msg.conversation.name, admin_conversation_path(msg.conversation)
        end
        column "Created", :created_at
      end
    end

    panel "Conversations" do
      table_for user.conversations.limit(10) do
        column "ID", :id
        column "Name", :name
        column "Type", :type
        column "Created", :created_at
        column "Actions" do |conv|
          link_to "View", admin_conversation_path(conv)
        end
      end
    end
  end

  # Form (edit/create)
  form do |f|
    f.inputs "User Details" do
      f.input :username
      f.input :email
      f.input :display_name
      f.input :bio
      f.input :online_status, as: :select, collection: ['online', 'offline', 'away']
    end
    f.actions
  end

  # Custom actions
  action_item :ban_user, only: :show do
    link_to "Ban User", ban_admin_user_path(user), method: :post, data: { confirm: "Are you sure?" }
  end

  member_action :ban, method: :post do
    user = User.find(params[:id])
    user.update(banned: true)
    redirect_to admin_user_path(user), notice: "User banned"
  end

  # Batch actions
  batch_action :ban do |ids|
    User.where(id: ids).update_all(banned: true)
    redirect_to collection_path, notice: "Users banned"
  end
end
```

---

### **2. Message Moderation**

```ruby
# app/admin/messages.rb
ActiveAdmin.register Message do
  menu priority: 2, label: "Messages"

  permit_params :content, :message_type

  # Scopes for filtering
  scope :all, default: true
  scope :reported do |messages|
    messages.where(reported: true)
  end
  scope :deleted do |messages|
    messages.where.not(deleted_at: nil)
  end
  scope :recent do |messages|
    messages.where('created_at > ?', 24.hours.ago)
  end

  # Filters
  filter :sender, as: :select, collection: -> { User.all }
  filter :conversation
  filter :content
  filter :message_type, as: :select, collection: ['text', 'image', 'file', 'system']
  filter :created_at
  filter :deleted_at

  # Index
  index do
    selectable_column
    id_column
    column :sender do |msg|
      link_to msg.sender.username, admin_user_path(msg.sender)
    end
    column :conversation do |msg|
      link_to msg.conversation.name, admin_conversation_path(msg.conversation)
    end
    column :content do |msg|
      truncate(msg.content, length: 80)
    end
    column :message_type
    column "Reported" do |msg|
      status_tag msg.reported? ? 'Yes' : 'No', msg.reported? ? :error : :ok
    end
    column :created_at
    column :deleted_at
    actions
  end

  # Show
  show do
    attributes_table do
      row :id
      row :sender do |msg|
        link_to msg.sender.username, admin_user_path(msg.sender)
      end
      row :conversation do |msg|
        link_to msg.conversation.name, admin_conversation_path(msg.conversation)
      end
      row :content
      row :message_type
      row :metadata
      row :edited_at
      row :deleted_at
      row :created_at
      row :updated_at
    end

    panel "Reactions" do
      table_for message.reactions do
        column :emoji
        column :user do |reaction|
          link_to reaction.user.username, admin_user_path(reaction.user)
        end
        column :created_at
      end
    end

    panel "Attachments" do
      if message.files.attached?
        message.files.each do |file|
          div do
            span file.filename.to_s
            span " (#{number_to_human_size(file.byte_size)})"
          end
        end
      else
        "No attachments"
      end
    end
  end

  # Custom actions
  action_item :delete_message, only: :show do
    link_to "Delete Message", delete_message_admin_message_path(message),
            method: :post,
            data: { confirm: "Delete this message?" }
  end

  member_action :delete_message, method: :post do
    message = Message.find(params[:id])
    message.update(deleted_at: Time.current, content: '[Message deleted by admin]')
    redirect_to admin_message_path(message), notice: "Message deleted"
  end

  # Batch actions
  batch_action :delete do |ids|
    Message.where(id: ids).update_all(
      deleted_at: Time.current,
      content: '[Message deleted by admin]'
    )
    redirect_to collection_path, notice: "Messages deleted"
  end

  batch_action :mark_as_reviewed do |ids|
    Message.where(id: ids).update_all(reported: false)
    redirect_to collection_path, notice: "Messages marked as reviewed"
  end
end
```

---

### **3. Conversation Management**

```ruby
# app/admin/conversations.rb
ActiveAdmin.register Conversation do
  menu priority: 3, label: "Conversations"

  permit_params :name, :description, :type

  # Filters
  filter :type, as: :select, collection: ['DirectConversation', 'GroupChat', 'Channel']
  filter :name
  filter :creator, as: :select, collection: -> { User.all }
  filter :created_at

  # Index
  index do
    selectable_column
    id_column
    column :name
    column :type
    column :creator do |conv|
      link_to conv.creator.username, admin_user_path(conv.creator) if conv.creator
    end
    column "Participants" do |conv|
      conv.participants.count
    end
    column "Messages" do |conv|
      conv.messages.count
    end
    column :last_message_at
    column :created_at
    actions
  end

  # Show
  show do
    attributes_table do
      row :id
      row :name
      row :description
      row :type
      row :creator do |conv|
        link_to conv.creator.username, admin_user_path(conv.creator) if conv.creator
      end
      row :settings
      row :last_message_at
      row :created_at
      row :updated_at
    end

    panel "Participants (#{conversation.participants.count})" do
      table_for conversation.participants do
        column :user do |participant|
          link_to participant.user.username, admin_user_path(participant.user)
        end
        column :role
        column :joined_at
        column :last_read_at
      end
    end

    panel "Recent Messages (#{conversation.messages.count} total)" do
      table_for conversation.messages.order(created_at: :desc).limit(20) do
        column :id
        column :sender do |msg|
          link_to msg.sender.username, admin_user_path(msg.sender)
        end
        column :content do |msg|
          truncate(msg.content, length: 100)
        end
        column :created_at
        column "Actions" do |msg|
          link_to "View", admin_message_path(msg)
        end
      end
    end
  end

  # Form
  form do |f|
    f.inputs "Conversation Details" do
      f.input :name
      f.input :description
      f.input :type, as: :select, collection: ['DirectConversation', 'GroupChat', 'Channel']
    end
    f.actions
  end
end
```

---

### **4. Dashboard (Custom Page)**

```ruby
# app/admin/dashboard.rb
ActiveAdmin.register_page "Dashboard" do
  menu priority: 0, label: proc { I18n.t("active_admin.dashboard") }

  content title: proc { I18n.t("active_admin.dashboard") } do
    columns do
      column do
        panel "Recent Stats (24h)" do
          para "Total Users: #{User.count}"
          para "New Users Today: #{User.where('created_at > ?', 24.hours.ago).count}"
          para "Total Messages: #{Message.count}"
          para "Messages Today: #{Message.where('created_at > ?', 24.hours.ago).count}"
          para "Active Conversations: #{Conversation.where('last_message_at > ?', 24.hours.ago).count}"
        end
      end

      column do
        panel "Moderation Queue" do
          para "Reported Messages: #{Message.where(reported: true).count}"
          para "Banned Users: #{User.where(banned: true).count}"
        end
      end
    end

    columns do
      column do
        panel "Recent Users" do
          table_for User.order(created_at: :desc).limit(10) do
            column "Username" do |user|
              link_to user.username, admin_user_path(user)
            end
            column "Email", :email
            column "Created", :created_at
          end
        end
      end

      column do
        panel "Recent Messages" do
          table_for Message.order(created_at: :desc).limit(10) do
            column "User" do |msg|
              link_to msg.sender.username, admin_user_path(msg.sender)
            end
            column "Content" do |msg|
              truncate(msg.content, length: 50)
            end
            column "Created", :created_at
          end
        end
      end
    end

    columns do
      column do
        panel "Most Active Users (7 days)" do
          users = User.joins(:messages)
                     .where('messages.created_at > ?', 7.days.ago)
                     .group('users.id')
                     .order('COUNT(messages.id) DESC')
                     .limit(10)
                     .select('users.*, COUNT(messages.id) as message_count')

          table_for users do
            column "Username" do |user|
              link_to user.username, admin_user_path(user)
            end
            column "Messages", :message_count
          end
        end
      end

      column do
        panel "Popular Conversations (7 days)" do
          convos = Conversation.joins(:messages)
                              .where('messages.created_at > ?', 7.days.ago)
                              .group('conversations.id')
                              .order('COUNT(messages.id) DESC')
                              .limit(10)
                              .select('conversations.*, COUNT(messages.id) as message_count')

          table_for convos do
            column "Name" do |conv|
              link_to conv.name, admin_conversation_path(conv)
            end
            column "Messages", :message_count
          end
        end
      end
    end
  end
end
```

---

## CSV Export

ActiveAdmin supports CSV export out of the box:

```ruby
# app/admin/users.rb
ActiveAdmin.register User do
  csv do
    column :id
    column :username
    column :email
    column :display_name
    column :created_at
    column("Messages Count") { |user| user.messages.count }
  end
end
```

**Export:** Click "CSV" button on index page → Downloads users.csv

---

## Custom Actions

### **Ban User**
```ruby
# app/admin/users.rb
action_item :ban, only: :show do
  if !resource.banned?
    link_to "Ban User", ban_admin_user_path(resource),
            method: :post,
            data: { confirm: "Ban this user?" }
  end
end

member_action :ban, method: :post do
  resource.update(banned: true)
  redirect_to resource_path, notice: "User banned successfully"
end
```

### **Send Notification**
```ruby
action_item :notify, only: :show do
  link_to "Send Notification", notify_admin_user_path(resource)
end

member_action :notify, method: :get do
  @user = resource
end

member_action :send_notification, method: :post do
  NotificationService.send_to_user(resource, params[:message])
  redirect_to resource_path, notice: "Notification sent"
end
```

---

## Batch Actions

```ruby
# Ban multiple users at once
batch_action :ban do |ids|
  User.where(id: ids).update_all(banned: true)
  redirect_to collection_path, notice: "Users banned"
end

# Delete multiple messages
batch_action :delete_messages do |ids|
  Message.where(id: ids).update_all(
    deleted_at: Time.current,
    content: '[Deleted by admin]'
  )
  redirect_to collection_path, notice: "Messages deleted"
end
```

---

## Security Best Practices

### **1. IP Whitelist (Production)**
```ruby
# config/initializers/active_admin.rb
ActiveAdmin.setup do |config|
  config.before_action do
    allowed_ips = ['127.0.0.1', 'your-office-ip']
    unless allowed_ips.include?(request.remote_ip) || Rails.env.development?
      redirect_to root_path, alert: 'Access denied'
    end
  end
end
```

### **2. Role-based Access**
```ruby
# app/models/admin_user.rb
class AdminUser < ApplicationRecord
  devise :database_authenticatable, :recoverable, :rememberable, :validatable

  def super_admin?
    role == 'super_admin'
  end
end

# app/admin/users.rb
ActiveAdmin.register User do
  controller do
    def destroy
      # Only super admins can delete users
      unless current_admin_user.super_admin?
        flash[:error] = "Only super admins can delete users"
        redirect_to admin_users_path and return
      end
      super
    end
  end
end
```

### **3. Audit Trail**
```ruby
# Log all admin actions
ActiveAdmin.setup do |config|
  config.after_action do
    AdminLog.create(
      admin_user: current_admin_user,
      action: params[:action],
      resource_type: controller_name,
      resource_id: params[:id],
      changes: resource.previous_changes if resource
    )
  end
end
```

---

## Common Use Cases

### **Customer Support: View User's Recent Activity**
1. Go to Users → Search by email
2. Click user → See recent messages & conversations
3. Check for issues, help troubleshoot

### **Content Moderation: Handle Reported Messages**
1. Go to Messages → Filter by "Reported"
2. Review message content
3. Delete inappropriate messages
4. Ban abusive users if needed

### **Analytics: Export User Data**
1. Go to Users
2. Apply filters (date range, etc.)
3. Click "CSV" → Download data
4. Analyze in Excel/Google Sheets

### **System Monitoring: Check Activity**
1. Dashboard → View stats
2. Recent users, messages, conversations
3. Monitor for unusual patterns

---

## Tips & Tricks

### **Quick Filters**
```ruby
# Add quick scope buttons
scope :all, default: true
scope :online do |users|
  users.where(online_status: 'online')
end
scope :premium do |users|
  users.where(premium: true)
end
```

### **Custom Columns**
```ruby
column "Custom" do |resource|
  # Any Ruby code
  resource.messages.count * 10
end
```

### **Search Everything**
```ruby
filter :id
filter :username
filter :email
filter :created_at
filter :messages_content, as: :string
```

---

## Summary

ActiveAdmin gives you:
- ✅ **User Management** - View, edit, ban users
- ✅ **Content Moderation** - Delete messages, review reports
- ✅ **Customer Support** - View user activity, troubleshoot
- ✅ **Analytics** - Export data, view stats
- ✅ **System Monitoring** - Dashboard, activity tracking

Access: `http://localhost:3000/admin`

---

**Happy Admin-ing! 👨‍💼**
