# Rswag API Documentation Guide for Chat API

Complete guide to using Rswag to auto-generate Swagger/OpenAPI documentation from RSpec tests.

---

## Access Swagger UI

```
URL: http://localhost:3000/api-docs
Interactive API explorer with "Try it out" buttons
```

---

## Core Concept: Tests = Documentation

```ruby
# ONE test file does TWO things:
# 1. Tests your API (RSpec)
# 2. Generates documentation (Swagger)

describe 'POST /api/v1/messages' do
  # ... rswag syntax ...
  run_test!  # ← Runs test AND generates docs!
end
```

---

## Basic Structure

```ruby
# spec/integration/api/v1/resource_spec.rb
require 'swagger_helper'

describe 'Resource API' do
  path '/api/v1/resource' do
    HTTP_METHOD 'Description' do
      tags 'Tag Name'
      consumes 'application/json'
      produces 'application/json'

      # Parameters
      parameter name: :param, in: :query, type: :string

      # Request body
      parameter name: :body, in: :body, schema: { ... }

      # Response
      response '200', 'success' do
        schema type: :object, properties: { ... }
        run_test!
      end
    end
  end
end
```

---

## Chat API Examples

### **1. Authentication - Register**

```ruby
# spec/integration/api/v1/auth/registration_spec.rb
require 'swagger_helper'

describe 'Authentication API' do
  path '/api/v1/auth/register' do
    post 'Register new user' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :user, in: :body, schema: {
        type: :object,
        properties: {
          email: { type: :string, format: :email, example: 'user@example.com' },
          username: { type: :string, example: 'john_doe' },
          password: { type: :string, format: :password, example: 'password123' },
          password_confirmation: { type: :string, format: :password }
        },
        required: ['email', 'username', 'password', 'password_confirmation']
      }

      response '201', 'user created' do
        schema type: :object,
          properties: {
            success: { type: :boolean, example: true },
            data: {
              type: :object,
              properties: {
                id: { type: :integer, example: 1 },
                email: { type: :string, example: 'user@example.com' },
                username: { type: :string, example: 'john_doe' },
                token: { type: :string, example: 'eyJhbGciOiJIUzI1NiJ9...' }
              }
            }
          }

        let(:user) { { email: 'test@example.com', username: 'testuser', password: 'password123', password_confirmation: 'password123' } }
        run_test!
      end

      response '422', 'invalid request' do
        schema type: :object,
          properties: {
            success: { type: :boolean, example: false },
            error: { type: :string, example: 'Email has already been taken' }
          }

        let(:user) { { email: 'invalid', username: '', password: '123' } }
        run_test!
      end
    end
  end

  path '/api/v1/auth/login' do
    post 'Login user' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :credentials, in: :body, schema: {
        type: :object,
        properties: {
          email: { type: :string, example: 'user@example.com' },
          password: { type: :string, format: :password }
        },
        required: ['email', 'password']
      }

      response '200', 'logged in' do
        schema type: :object,
          properties: {
            success: { type: :boolean },
            data: {
              type: :object,
              properties: {
                user: {
                  type: :object,
                  properties: {
                    id: { type: :integer },
                    email: { type: :string },
                    username: { type: :string }
                  }
                },
                token: { type: :string }
              }
            }
          }

        let(:credentials) { { email: 'user@example.com', password: 'password123' } }
        run_test!
      end

      response '401', 'unauthorized' do
        let(:credentials) { { email: 'wrong@example.com', password: 'wrong' } }
        run_test!
      end
    end
  end
end
```

---

### **2. Messages - CRUD with Authentication**

```ruby
# spec/integration/api/v1/messages_spec.rb
require 'swagger_helper'

describe 'Messages API' do
  # Setup authenticated user
  let(:user) { create(:user) }
  let(:token) { JWT.encode({ user_id: user.id }, Rails.application.secret_key_base) }
  let(:Authorization) { "Bearer #{token}" }
  let(:conversation) { create(:conversation) }

  path '/api/v1/conversations/{conversation_id}/messages' do
    parameter name: :conversation_id, in: :path, type: :integer, description: 'Conversation ID'

    get 'List messages' do
      tags 'Messages'
      produces 'application/json'
      security [Bearer: []]

      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :per_page, in: :query, type: :integer, required: false, description: 'Items per page (default: 50)'
      parameter name: :before_id, in: :query, type: :integer, required: false, description: 'Cursor-based pagination: Load messages before this ID'
      parameter name: :after_id, in: :query, type: :integer, required: false, description: 'Load messages after this ID'

      response '200', 'messages retrieved' do
        schema type: :object,
          properties: {
            messages: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  id: { type: :integer },
                  content: { type: :string },
                  message_type: { type: :string, enum: ['text', 'image', 'file', 'system'] },
                  user: {
                    type: :object,
                    properties: {
                      id: { type: :integer },
                      username: { type: :string },
                      display_name: { type: :string },
                      avatar_url: { type: :string, nullable: true }
                    }
                  },
                  edited: { type: :boolean },
                  created_at: { type: :string, format: 'date-time' }
                }
              }
            },
            has_more: { type: :boolean },
            cursors: {
              type: :object,
              properties: {
                before: { type: :integer, nullable: true },
                after: { type: :integer, nullable: true }
              }
            }
          }

        let(:conversation_id) { conversation.id }
        run_test!
      end

      response '401', 'unauthorized' do
        let(:Authorization) { 'Bearer invalid' }
        let(:conversation_id) { conversation.id }
        run_test!
      end

      response '404', 'conversation not found' do
        let(:conversation_id) { 999999 }
        run_test!
      end
    end

    post 'Create message' do
      tags 'Messages'
      consumes 'application/json'
      produces 'application/json'
      security [Bearer: []]

      parameter name: :message, in: :body, schema: {
        type: :object,
        properties: {
          content: { type: :string, example: 'Hello, world!' },
          message_type: { type: :string, enum: ['text', 'image', 'file'], default: 'text' },
          reply_to_id: { type: :integer, nullable: true, description: 'ID of message being replied to' },
          metadata: {
            type: :object,
            additionalProperties: true,
            description: 'Custom metadata (mentions, links, etc.)'
          }
        },
        required: ['content']
      }

      response '201', 'message created' do
        schema type: :object,
          properties: {
            id: { type: :integer },
            content: { type: :string },
            message_type: { type: :string },
            user: { type: :object },
            created_at: { type: :string, format: 'date-time' }
          }

        let(:conversation_id) { conversation.id }
        let(:message) { { content: 'Test message' } }
        run_test!
      end

      response '422', 'invalid request' do
        let(:conversation_id) { conversation.id }
        let(:message) { { content: '' } }  # Empty content
        run_test!
      end
    end
  end

  path '/api/v1/conversations/{conversation_id}/messages/{id}' do
    parameter name: :conversation_id, in: :path, type: :integer
    parameter name: :id, in: :path, type: :integer, description: 'Message ID'

    get 'Show message' do
      tags 'Messages'
      produces 'application/json'
      security [Bearer: []]

      response '200', 'message found' do
        let(:conversation_id) { conversation.id }
        let(:id) { create(:message, conversation: conversation).id }
        run_test!
      end
    end

    patch 'Edit message' do
      tags 'Messages'
      consumes 'application/json'
      produces 'application/json'
      security [Bearer: []]

      parameter name: :message, in: :body, schema: {
        type: :object,
        properties: {
          content: { type: :string }
        },
        required: ['content']
      }

      response '200', 'message updated' do
        let(:conversation_id) { conversation.id }
        let(:id) { create(:message, conversation: conversation, sender: user).id }
        let(:message) { { content: 'Updated content' } }
        run_test!
      end

      response '403', 'forbidden (not message owner)' do
        let(:other_user) { create(:user) }
        let(:conversation_id) { conversation.id }
        let(:id) { create(:message, conversation: conversation, sender: other_user).id }
        let(:message) { { content: 'Updated' } }
        run_test!
      end
    end

    delete 'Delete message' do
      tags 'Messages'
      produces 'application/json'
      security [Bearer: []]

      response '204', 'message deleted' do
        let(:conversation_id) { conversation.id }
        let(:id) { create(:message, conversation: conversation, sender: user).id }
        run_test!
      end
    end
  end
end
```

---

### **3. Conversations**

```ruby
# spec/integration/api/v1/conversations_spec.rb
require 'swagger_helper'

describe 'Conversations API' do
  let(:user) { create(:user) }
  let(:token) { JWT.encode({ user_id: user.id }, Rails.application.secret_key_base) }
  let(:Authorization) { "Bearer #{token}" }

  path '/api/v1/conversations' do
    get 'List user conversations' do
      tags 'Conversations'
      produces 'application/json'
      security [Bearer: []]

      parameter name: :type, in: :query, type: :string, required: false,
                description: 'Filter by type',
                schema: { enum: ['DirectConversation', 'GroupChat', 'Channel'] }
      parameter name: :page, in: :query, type: :integer, required: false

      response '200', 'conversations retrieved' do
        schema type: :array,
          items: {
            type: :object,
            properties: {
              id: { type: :integer },
              name: { type: :string },
              type: { type: :string },
              last_message: { type: :object, nullable: true },
              unread_count: { type: :integer },
              participant_count: { type: :integer },
              last_message_at: { type: :string, format: 'date-time', nullable: true }
            }
          }

        run_test!
      end
    end

    post 'Create conversation' do
      tags 'Conversations'
      consumes 'application/json'
      produces 'application/json'
      security [Bearer: []]

      parameter name: :conversation, in: :body, schema: {
        type: :object,
        properties: {
          type: { type: :string, enum: ['DirectConversation', 'GroupChat', 'Channel'] },
          name: { type: :string, description: 'Required for GroupChat and Channel' },
          description: { type: :string, nullable: true },
          participant_ids: { type: :array, items: { type: :integer } }
        },
        required: ['type']
      }

      response '201', 'conversation created' do
        let(:conversation) { { type: 'GroupChat', name: 'Team Chat', participant_ids: [user.id] } }
        run_test!
      end

      response '422', 'invalid request' do
        let(:conversation) { { type: 'GroupChat' } }  # Missing name
        run_test!
      end
    end
  end
end
```

---

### **4. Reactions**

```ruby
# spec/integration/api/v1/reactions_spec.rb
require 'swagger_helper'

describe 'Reactions API' do
  let(:user) { create(:user) }
  let(:token) { JWT.encode({ user_id: user.id }, Rails.application.secret_key_base) }
  let(:Authorization) { "Bearer #{token}" }
  let(:message) { create(:message) }

  path '/api/v1/messages/{message_id}/reactions' do
    parameter name: :message_id, in: :path, type: :integer

    post 'Add reaction' do
      tags 'Reactions'
      consumes 'application/json'
      produces 'application/json'
      security [Bearer: []]

      parameter name: :reaction, in: :body, schema: {
        type: :object,
        properties: {
          emoji: { type: :string, example: '👍', description: 'Emoji character' }
        },
        required: ['emoji']
      }

      response '201', 'reaction added' do
        schema type: :object,
          properties: {
            id: { type: :integer },
            emoji: { type: :string },
            user: { type: :object },
            created_at: { type: :string, format: 'date-time' }
          }

        let(:message_id) { message.id }
        let(:reaction) { { emoji: '👍' } }
        run_test!
      end
    end

    get 'List reactions' do
      tags 'Reactions'
      produces 'application/json'

      response '200', 'reactions retrieved' do
        schema type: :array,
          items: {
            type: :object,
            properties: {
              emoji: { type: :string },
              count: { type: :integer },
              users: { type: :array, items: { type: :object } }
            }
          }

        let(:message_id) { message.id }
        run_test!
      end
    end
  end

  path '/api/v1/messages/{message_id}/reactions/{emoji}' do
    parameter name: :message_id, in: :path, type: :integer
    parameter name: :emoji, in: :path, type: :string, description: 'URL-encoded emoji'

    delete 'Remove reaction' do
      tags 'Reactions'
      produces 'application/json'
      security [Bearer: []]

      response '204', 'reaction removed' do
        let(:message_id) { message.id }
        let(:emoji) { CGI.escape('👍') }
        run_test!
      end
    end
  end
end
```

---

## Advanced Features

### **Reusable Schemas**

```ruby
# spec/swagger_helper.rb
RSpec.configure do |config|
  config.swagger_docs = {
    'v1/swagger.yaml' => {
      # ... other config ...
      components: {
        schemas: {
          User: {
            type: :object,
            properties: {
              id: { type: :integer },
              username: { type: :string },
              email: { type: :string },
              display_name: { type: :string }
            }
          },
          Message: {
            type: :object,
            properties: {
              id: { type: :integer },
              content: { type: :string },
              sender: { '$ref' => '#/components/schemas/User' },
              created_at: { type: :string, format: 'date-time' }
            }
          },
          Error: {
            type: :object,
            properties: {
              success: { type: :boolean, example: false },
              error: { type: :string }
            }
          }
        }
      }
    }
  }
end

# Use in specs:
response '200', 'success' do
  schema '$ref' => '#/components/schemas/Message'
  run_test!
end
```

---

### **File Upload Documentation**

```ruby
path '/api/v1/media/upload' do
  post 'Upload file' do
    tags 'Media'
    consumes 'multipart/form-data'
    produces 'application/json'
    security [Bearer: []]

    parameter name: :file, in: :formData, type: :file, required: true, description: 'File to upload'
    parameter name: :message_id, in: :formData, type: :integer, required: false

    response '201', 'file uploaded' do
      schema type: :object,
        properties: {
          id: { type: :integer },
          filename: { type: :string },
          url: { type: :string },
          size: { type: :integer },
          content_type: { type: :string }
        }

      let(:file) { Rack::Test::UploadedFile.new('spec/fixtures/files/test.png', 'image/png') }
      run_test!
    end
  end
end
```

---

### **Pagination Documentation**

```ruby
parameter name: :page, in: :query, type: :integer, required: false, default: 1
parameter name: :per_page, in: :query, type: :integer, required: false, default: 50, maximum: 100

response '200', 'paginated results' do
  schema type: :object,
    properties: {
      data: { type: :array, items: { '$ref' => '#/components/schemas/Message' } },
      pagination: {
        type: :object,
        properties: {
          current_page: { type: :integer },
          total_pages: { type: :integer },
          total_count: { type: :integer },
          per_page: { type: :integer }
        }
      }
    }
  run_test!
end
```

---

## Workflow

### **1. Write Test + Documentation**
```ruby
# spec/integration/api/v1/messages_spec.rb
describe 'POST /api/v1/messages' do
  # ... rswag syntax ...
  run_test!
end
```

### **2. Run Tests**
```bash
rspec spec/integration/api/v1/messages_spec.rb
# Tests pass ✅
```

### **3. Generate Docs**
```bash
rake rswag:specs:swaggerize
# Swagger YAML generated ✅
```

### **4. View in Browser**
```
http://localhost:3000/api-docs
# Interactive docs ✅
```

---

## Tips & Best Practices

### **1. Tag Organization**
```ruby
# Group by feature
tags 'Authentication'  # All auth endpoints
tags 'Messages'        # All message endpoints
tags 'Users'           # All user endpoints
```

### **2. Examples**
```ruby
# Add examples to parameters
parameter name: :email, in: :body, schema: {
  type: :string,
  example: 'user@example.com'  # ← Shows in docs!
}
```

### **3. Descriptions**
```ruby
# Document everything
parameter name: :before_id,
  in: :query,
  type: :integer,
  required: false,
  description: 'Cursor-based pagination: Load messages before this ID'
```

### **4. Error Responses**
```ruby
# Document all error cases
response '401', 'unauthorized'
response '403', 'forbidden'
response '404', 'not found'
response '422', 'validation error'
response '500', 'server error'
```

---

## CI/CD Integration

```yaml
# .github/workflows/ci.yml
- name: Generate API docs
  run: |
    bundle exec rake rswag:specs:swaggerize

- name: Verify docs are up to date
  run: |
    git diff --exit-code swagger/
```

---

## Summary

Rswag gives you:
- ✅ **Auto-generated docs** from tests
- ✅ **Interactive Swagger UI**
- ✅ **Always in sync** (tests = docs)
- ✅ **OpenAPI 3.0** standard
- ✅ **Try it out** buttons
- ✅ **Code generation** for clients

Access: `http://localhost:3000/api-docs`

Generate: `rake rswag:specs:swaggerize`

---

**Happy Documenting! 📚**
