module ClientPortal
  class SessionService
    COOKIE_NAME = :client_form_session

    def self.set_cookie(cookies, client_form)
      expires_at = client_form.expires_at || 7.days.from_now
      cookies.signed[COOKIE_NAME] = {
        value: client_form.access_token,
        httponly: true,
        secure: true,
        same_site: :strict,
        expires: expires_at
      }
    end

    def self.clear_cookie(cookies)
      cookies.delete(COOKIE_NAME)
    end

    def self.current_client_form(cookies)
      token = cookies.signed[COOKIE_NAME]
      return nil unless token.present?
      ClientForm.find_by(access_token: token)
    end
  end
end
