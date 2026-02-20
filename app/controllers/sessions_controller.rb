class SessionsController < ApplicationController

  skip_before_action :authenticate, only: %i[ new create omniauth ]

  before_action :set_session, only: :destroy

  def index
    @sessions = Current.user.sessions.order(created_at: :desc)
  end

  def new
    render inertia: true
  end

  def create
    if user = User.authenticate_by(email: params[:email], password: params[:password])
      start_user_session!(user)

      redirect_to auth_loading_path, notice: "Signed in successfully", status: :see_other
    else
      redirect_to sign_in_path(email_hint: params[:email]), alert: "That email or password is incorrect"
    end
  end

  def destroy
    @session.destroy
    redirect_to sessions_path, notice: "That session has been logged out"
  end

  def omniauth
    user = find_or_build_oauth_user

    if user&.persisted?
      start_user_session!(user)
      redirect_to auth_loading_path, notice: "Signed in successfully", status: :see_other
    else
      oauth_failure_redirect
    end
  rescue ActiveRecord::RecordInvalid
    oauth_failure_redirect
  end

  private

    def start_user_session!(user)
      @session = user.sessions.create!
      cookies.permanent.signed[:session_token] = @session.id
    end

    def find_or_build_oauth_user
      provider = oauth_provider
      uid = oauth_uid
      email = oauth_email
      return nil if provider.blank? || uid.blank? || email.blank?

      User.find_by(provider: provider, uid: uid) ||
        find_or_link_user_by_email(provider: provider, uid: uid, email: email) ||
        create_oauth_user(provider: provider, uid: uid, email: email)
    end

    def find_or_link_user_by_email(provider:, uid:, email:)
      user = User.find_by(email: email)
      return nil unless user

      return nil if user.provider.present? && (user.provider != provider || user.uid != uid)

      user.update!(provider: provider, uid: uid) if user.provider.blank? || user.uid.blank?
      user
    end

    def create_oauth_user(provider:, uid:, email:)
      generated_password = SecureRandom.base58(24)

      User.create!(
        email: email,
        provider: provider,
        uid: uid,
        password: generated_password,
        password_confirmation: generated_password
      )
    end

    def oauth_auth
      raw = request.env["omniauth.auth"] || {}
      raw = raw.to_h if raw.respond_to?(:to_h)
      raw.with_indifferent_access
    rescue => _e
      {}
    end

    def oauth_provider
      oauth_auth["provider"] || oauth_auth[:provider]
    end

    def oauth_uid
      oauth_auth["uid"] || oauth_auth[:uid]
    end

    def oauth_email
      email = oauth_auth.dig("info", "email") || oauth_auth.dig(:info, :email)
      email&.downcase
    end

    def set_session
      @session = Current.user.sessions.find(params[:id])
    end

    def oauth_failure_redirect
      redirect_to sign_in_path, alert: "We could not sign you in with Google"
    end

    def current_user
      Current.session&.user
    end

end
