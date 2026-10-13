Rails.application.config.to_prepare do
  # Reset registry on reload in development
  Mcp::Registry.reset!

  # Register baseline tools
  Mcp::Registry.register(Mcp::Tools::HelloTool.new, scopes: %i[all read action knowledge task])

  # Register all tool classes found under app/services/mcp/tools/
  Dir[Rails.root.join("app/services/mcp/tools/**/*.rb")].each do |file|
    require_dependency file
  end
end
