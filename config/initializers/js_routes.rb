JsRoutes.setup do |c|
  # Setup your JS module system:
  # ESM, CJS, AMD, UMD or nil.
  # c.module_type = "ESM"

  # Legacy setup for no modules system.
  # Sets up a global variable `Routes`
  # that holds route helpers.
  # c.module_type = nil
  # c.namespace = "Routes"

  # Follow javascript naming convention
  # but lose the ability to match helper name
  # on backend and frontend consistently.
  # c.camel_case = true

  # Generate only helpers that match specific pattern.
  # c.exclude = /^api_/
  # c.include = /^admin_/

  # Generate `*_url` helpers besides `*_path`
  # for apps that work on multiple domains.
  # c.url_links = true

  c.file = Rails.root.join("app/frontend/routes/index.js")

  # More options:
  # @see https://github.com/railsware/js-routes#available-options
end

# Ensure the routes file is generated during initialization if it's missing,
# which is common during Docker/CI asset precompilation.
if Rails.env.production? && ENV["SECRET_KEY_BASE_DUMMY"].present?
  JsRoutes.generate!
end
