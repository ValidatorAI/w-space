require_relative "boot"

require "rails/all"

Bundler.require(*Rails.groups)

module Space
  class Application < Rails::Application
    # Initialize configuration defaults for the app's supported Rails version.
    config.load_defaults 8.2

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks rails_ext])

    # Fallback to English if translation key is missing
    config.i18n.fallbacks = true

    # Embed anti-CSRF authenticity token in all forms including remote forms
    config.action_view.embed_authenticity_token_in_remote_forms = true
  end
end
