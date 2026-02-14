class Api::BaseController < ActionController::API
  include ActionController::HttpAuthentication::Token::ControllerMethods

  # Error handling
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :record_invalid
  rescue_from ActionController::ParameterMissing, with: :parameter_missing

  before_action :authenticate

  private

  def authenticate
    authenticate_or_request_with_http_token do |token, options|
      # Simple token authentication - compare with ENV variable or default for development
      expected_token = ENV['API_TOKEN'] ||
                       (Rails.env.development? ? 'development_token' : Rails.application.credentials.api_token)

      return false unless expected_token

      ActiveSupport::SecurityUtils.secure_compare(token, expected_token)
    end
  end

  def record_not_found(exception)
    render json: { error: 'Record not found', message: exception.message }, status: :not_found
  end

  def record_invalid(exception)
    render json: { error: 'Validation failed', errors: exception.record.errors.full_messages }, status: :unprocessable_entity
  end

  def parameter_missing(exception)
    render json: { error: 'Parameter missing', message: exception.message }, status: :bad_request
  end
end
