module Hermes
  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield(configuration) if block_given?
    configuration
  end

  def self.reset_configuration!
    @configuration = Configuration.new
  end
end
