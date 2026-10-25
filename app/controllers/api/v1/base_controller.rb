module Api
  module V1
    class BaseController < ActionController::API
      include ActionController::HttpAuthentication::Token::ControllerMethods

      class InvalidParameters < StandardError
        attr_reader :errors

        def initialize(errors)
          @errors = errors
          super("Invalid parameters")
        end
      end

      class NotFound < StandardError; end

      rescue_from InvalidParameters, with: :render_invalid_parameters
      rescue_from ActionController::ParameterMissing, with: :render_parameter_missing
      rescue_from ActionDispatch::Http::Parameters::ParseError, with: :render_malformed_json
      rescue_from NotFound, with: :render_not_found

      wrap_parameters false

      before_action :authenticate!

      private

      def authenticate!
        @current_client = authenticate_with_http_token { |token| ApiClientRegistry.instance.find_by_token(token) }
        render_unauthorized unless @current_client
      end

      def render_data(resource, status: :ok)
        render json: { data: resource }, status: status
      end

      def render_errors(errors, status: :unprocessable_content)
        render json: { errors: errors }, status: status
      end

      def render_validation_errors(record)
        errors = record.errors.map do |error|
          { code: error.type.to_s, field: error.attribute.to_s, message: error.message }
        end
        render_errors errors, status: :unprocessable_content
      end

      def not_found!
        raise NotFound
      end

      def require_attributes(key, allowed)
        raw = params.require(key)
        raise ActionController::ParameterMissing, key unless raw.is_a?(ActionController::Parameters)

        permitted = raw.permit(*allowed)
        rejected = raw.keys - permitted.keys
        raise InvalidParameters, rejected.map { |field| rejected_field_error(field, allowed) } if rejected.any?

        permitted
      end

      def rejected_field_error(field, allowed)
        if allowed.map(&:to_s).include?(field.to_s)
          { code: "invalid_type", field: field, message: I18n.t("errors.messages.not_a_string") }
        else
          { code: "unknown_field", field: field, message: "is not a recognised field" }
        end
      end

      def render_invalid_parameters(exception)
        render_errors(exception.errors, status: :unprocessable_content)
      end

      def render_parameter_missing(error)
        render_errors(
          [ { code: "parameter_missing", field: error.param.to_s, message: "is required and must be a JSON object" } ],
          status: :bad_request
        )
      end

      def render_malformed_json
        render_errors(
          [ { code: "malformed_json", field: "body", message: "is not valid JSON" } ],
          status: :bad_request
        )
      end

      def render_not_found
        render_errors(
          [ { code: "not_found", field: "id", message: "does not match an existing record" } ],
          status: :not_found
        )
      end

      def render_unauthorized
        response.headers["WWW-Authenticate"] = "Bearer"
        render_errors(
          [ { code: "unauthorized", field: "authorization", message: "a valid bearer token is required" } ],
          status: :unauthorized
        )
      end
    end
  end
end
