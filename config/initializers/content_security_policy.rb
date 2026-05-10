# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self, :https
    policy.base_uri :self
    policy.connect_src :self, :https
    policy.font_src :self, :https, :data
    policy.img_src :self, :https, :data, :blob
    policy.object_src :none
    policy.frame_ancestors :none
    # Chrome enforces form-action across OAuth redirect chains, so same-origin
    # OmniAuth POSTs still need the provider authorize host to be allowlisted.
    policy.form_action :self, "https://accounts.google.com"
    policy.script_src :self, :https
    policy.style_src :self, :https

    if Rails.env.development?
      vite_host = "http://#{ViteRuby.config.host_with_port}"
      policy.connect_src *policy.connect_src, vite_host, :ws, :wss
      policy.script_src *policy.script_src, :unsafe_eval, vite_host
      policy.style_src *policy.style_src, :unsafe_inline
    end
  end
end
