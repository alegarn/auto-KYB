class ApplicationController < ActionController::Base
  CRM_TRANSFER_TOAST_SEEN_AT_SESSION_KEY = :crm_transfer_failure_toast_seen_at

  include Pagy::Backend
  include Pundit::Authorization

  rescue_from ActionController::InvalidAuthenticityToken, with: :inertia_page_expired_error
  rescue_from Pundit::NotAuthorizedError, with: :pundit_not_authorized

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :set_current_request_details
  before_action :set_current_user
  before_action :authenticate

  helper_method :current_user, :current_session_id, :user_props, :default_inertia_props

  inertia_share flash: -> { flash.to_hash },
               session_id: -> { current_session_id },
               crm_transfer_signals: -> { crm_transfer_signals_props },
               auth: -> {
                 user = current_user
                 next nil unless user

                 {
                   user: {
                     id:                   user.id,
                     email:                user.email,
                     onboarding_completed: user.onboarding_completed
                   },
                   subscription: {
                     status:      user.subscription_status,
                     active:      user.active_subscription? || user.trialing?,
                     canceled_at: user.subscription_canceled_at&.iso8601
                   }
                 }
               }

  def current_user
    Current.session&.user
  end

  def current_session_id
    Current.session&.id
  end

  def user_props
    return nil unless current_user

    { id: current_user.id, email: current_user.email }
  end

  def default_inertia_props
    {
      user: user_props
    }
  end

  def store_client_form_one_time_password(client_form, password, expires_in: 5.minutes)
    session[:client_form_one_time_passwords] ||= {}
    session[:client_form_one_time_passwords][client_form.id.to_s] = {
      password: password,
      expires_at: expires_in.from_now.iso8601
    }
  end

  private
    def set_current_user
      return if Current.session&.user.present?

      token = cookies.signed[:session_token] || cookies[:session_token] || request.cookies["session_token"]
      if session_record = Session.find_by(id: token)
        if session_record.user.present?
          Current.session = session_record
        end
      end
    end

    def authenticate
      # Allow tests that set Current.session directly to bypass cookie-based lookup
      return if Current.session&.user.present?

      redirect_to(sign_in_path) and return
    end

    def set_current_request_details
      # Prefer request headers but fall back to common test env keys so controller specs work
      Current.user_agent = request.env["HTTP_USER_AGENT"] || request.headers["User-Agent"] || request.user_agent
      Current.ip_address = request.env["REMOTE_ADDR"] || request.remote_ip || request.ip
    end

    def crm_transfer_signals_props
      return nil unless current_user

      payload = CrmTransferSignalsQuery.new(
        user: current_user,
        toast_seen_at: crm_transfer_toast_seen_at
      ).call

      advance_crm_transfer_toast_marker_from_payload!(payload)

      payload
    end

    def crm_transfer_toast_seen_at
      session[CRM_TRANSFER_TOAST_SEEN_AT_SESSION_KEY]
    end

    def advance_crm_transfer_toast_marker!(timestamp)
      normalized_timestamp = normalize_crm_transfer_timestamp(timestamp)
      return if normalized_timestamp.blank?

      session[CRM_TRANSFER_TOAST_SEEN_AT_SESSION_KEY] = normalized_timestamp
    end

    def advance_crm_transfer_toast_marker_from_payload!(payload)
      return if crm_transfer_signals_value(payload, :toast).blank?

      advance_crm_transfer_toast_marker!(crm_transfer_signals_value(payload, :latest_unread_failure_at))
    end

    def crm_transfer_signals_value(payload, key)
      return nil unless payload.respond_to?(:[])

      payload[key] || payload[key.to_s]
    end

    def normalize_crm_transfer_timestamp(timestamp)
      case timestamp
      when ActiveSupport::TimeWithZone, Time, DateTime
        timestamp.iso8601
      when String
        timestamp
      end
    end

    def inertia_page_expired_error
      redirect_back_or_to("/", allow_other_host: false,
        notice: "The page expired, please try again.")
    end

    def pundit_not_authorized
      if current_user
        redirect_to subscription_required_path,
                    alert: "You need an active subscription to access this page."
      else
        redirect_to sign_in_path
      end
    end

end
