module Api
  module V1
    class BaseController < ActionController::API
      class InvalidParameters < StandardError
        attr_reader :errors

        def initialize(errors)
          @errors = errors
          super("Invalid parameters")
        end
      end

      rescue_from InvalidParameters, with: :render_invalid_parameters
      rescue_from ActionController::ParameterMissing, with: :render_parameter_missing

      wrap_parameters false

      private

      def render_data(resource, status: :ok)
        render json: { data: resource }, status: status
      end

      def render_errors(errors, status: :unprocessable_entity)
        render json: { errors: errors }, status: status
      end

      def render_validation_errors(record)
        errors = record.errors.map do |error|
          { code: error.type.to_s, field: error.attribute.to_s, message: error.message }
        end
        render_errors errors, status: :unprocessable_entity
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
          { code: "invalid_type", field: field, message: "must be a string" }
        else
          { code: "unknown_field", field: field, message: "is not a recognised field" }
        end
      end

      def render_invalid_parameters(exception)
        render_errors(exception.errors, status: :unprocessable_entity)
      end

      def render_parameter_missing(error)
        render_errors(
          [ { code: "parameter_missing", field: error.param.to_s, message: "is required and must be a JSON object" } ],
          status: :bad_request
        )
      end
    end
  end
end
