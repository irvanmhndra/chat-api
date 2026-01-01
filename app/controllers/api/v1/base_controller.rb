# app/controllers/api/v1/base_controller.rb
module Api
  module V1
    class BaseController < ApplicationController
      # Disable CSRF for API
      skip_before_action :verify_authenticity_token

      # =============================================================================
      # ERROR HANDLING - Industry Standard Approach
      # =============================================================================
      # - 4xx errors: Client mistakes (log as info, don't alert)
      # - 5xx errors: Server issues (log as error, trigger alerts)
      # - Consistent JSON format with error type + request_id
      # - Environment-aware details (safe in production)
      # =============================================================================

      # Exception to HTTP Status Mapping
      rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
      rescue_from ActiveRecord::RecordInvalid, with: :handle_validation_error
      rescue_from ActionController::ParameterMissing, with: :handle_bad_request
      rescue_from ActiveRecord::RecordNotUnique, with: :handle_conflict
      rescue_from StandardError, with: :handle_internal_error

      # Future: Add when implementing authentication/authorization
      # rescue_from JWT::DecodeError, with: :handle_unauthorized
      # rescue_from Pundit::NotAuthorizedError, with: :handle_forbidden

      # =============================================================================
      # SUCCESS RESPONSE
      # =============================================================================

      def render_success(data, status: :ok, meta: {})
        response = { data: data }
        response[:meta] = meta if meta.present?
        render json: response, status: status
      end

      # =============================================================================
      # ERROR HANDLERS (4xx - Client Errors)
      # =============================================================================

      # 400 Bad Request - Missing/invalid parameters
      def handle_bad_request(exception)
        log_client_error(exception, :bad_request)
        render_error(
          type: 'bad_request',
          message: exception.message,
          status: :bad_request
        )
      end

      # 404 Not Found - Resource doesn't exist
      def handle_not_found(exception)
        log_client_error(exception, :not_found)
        render_error(
          type: 'not_found',
          message: exception.message,
          status: :not_found
        )
      end

      # 409 Conflict - Duplicate resource (unique constraint violation)
      def handle_conflict(exception)
        log_client_error(exception, :conflict)
        render_error(
          type: 'conflict',
          message: 'Resource already exists',
          details: extract_conflict_details(exception),
          status: :conflict
        )
      end

      # 422 Unprocessable Entity - Validation errors
      def handle_validation_error(exception)
        log_client_error(exception, :unprocessable_entity)
        render_error(
          type: 'validation_error',
          message: 'Validation failed',
          details: extract_validation_errors(exception),
          status: :unprocessable_entity
        )
      end

      # Future: 401 Unauthorized - Not authenticated
      def handle_unauthorized(exception)
        log_client_error(exception, :unauthorized)
        render_error(
          type: 'unauthorized',
          message: 'Authentication required',
          status: :unauthorized
        )
      end

      # Future: 403 Forbidden - Not authorized
      def handle_forbidden(exception)
        log_client_error(exception, :forbidden)
        render_error(
          type: 'forbidden',
          message: 'You are not authorized to perform this action',
          status: :forbidden
        )
      end

      # =============================================================================
      # ERROR HANDLERS (5xx - Server Errors)
      # =============================================================================

      # 500 Internal Server Error - Unexpected exceptions
      def handle_internal_error(exception)
        log_server_error(exception)

        # Send to error tracking service (Sentry, Rollbar, etc.)
        capture_exception(exception)

        render_error(
          type: 'internal_error',
          message: server_error_message(exception),
          details: server_error_details(exception),
          status: :internal_server_error
        )
      end

      # =============================================================================
      # ERROR RESPONSE FORMATTER
      # =============================================================================

      def render_error(type:, message:, status:, details: nil)
        error_response = {
          error: {
            type: type,
            message: message,
            request_id: request.request_id,
            timestamp: Time.current.iso8601
          }
        }

        error_response[:error][:details] = details if details.present?

        render json: error_response, status: status
      end

      private

      # =============================================================================
      # VALIDATION ERROR EXTRACTION
      # =============================================================================

      def extract_validation_errors(exception)
        return {} unless exception.respond_to?(:record)

        exception.record.errors.messages.transform_values do |messages|
          messages.map(&:to_s)
        end
      end

      # =============================================================================
      # CONFLICT ERROR EXTRACTION
      # =============================================================================

      def extract_conflict_details(exception)
        # Extract field name from unique constraint error
        # Example: "PG::UniqueViolation: ERROR:  duplicate key value violates unique constraint \"index_users_on_email\""
        if exception.message =~ /index_\w+_on_(\w+)/
          { field: Regexp.last_match(1) }
        else
          {}
        end
      end

      # =============================================================================
      # SERVER ERROR MESSAGES (Environment-Aware)
      # =============================================================================

      def server_error_message(exception)
        if Rails.env.production?
          # Generic message - don't leak internals
          "An unexpected error occurred. Please contact support with request_id: #{request.request_id}"
        else
          # Detailed message for development
          "#{exception.class}: #{exception.message}"
        end
      end

      def server_error_details(exception)
        return nil if Rails.env.production?

        # Only include details in development/test
        {
          exception: exception.class.name,
          message: exception.message,
          backtrace: exception.backtrace&.first(10) # First 10 lines only
        }
      end

      # =============================================================================
      # LOGGING (Different levels for 4xx vs 5xx)
      # =============================================================================

      def log_client_error(exception, status)
        # 4xx = Expected client errors, log as info (don't trigger alerts)
        Rails.logger.info do
          "[#{status.to_s.upcase}] #{exception.class}: #{exception.message} | " \
          "Request ID: #{request.request_id} | " \
          "Path: #{request.path} | " \
          "Params: #{request.params.except('controller', 'action').to_json}"
        end
      end

      def log_server_error(exception)
        # 5xx = Unexpected server errors, log as error (trigger alerts)
        Rails.logger.error do
          "[INTERNAL ERROR] #{exception.class}: #{exception.message} | " \
          "Request ID: #{request.request_id} | " \
          "Path: #{request.path} | " \
          "Params: #{request.params.except('controller', 'action').to_json}"
        end
        Rails.logger.error(exception.backtrace.join("\n"))
      end

      # =============================================================================
      # ERROR TRACKING SERVICE INTEGRATION
      # =============================================================================

      def capture_exception(exception)
        # Sentry integration (when configured)
        if defined?(Sentry)
          Sentry.capture_exception(exception)
        end

        # Add other error tracking services here:
        # - Rollbar.error(exception)
        # - Honeybadger.notify(exception)
        # - Airbrake.notify(exception)
      end
    end
  end
end