source "https://rubygems.org"

git_source(:github) { |repo| "https://github.com/#{repo}.git" }

# Rails
# The app was generated against the Rails 8.2-era API surface, which is only available on the upstream main branch in this environment.
gem "rails", github: "rails/rails", branch: "main"
gem "ostruct"
gem "benchmark"

# Drivers
gem "sqlite3"
gem "redis", "~> 5.4"
gem "redis-client", ">= 0.28.0"

# Deployment
gem "puma", "~> 6.6"

# Jobs
gem "resque", "~> 2.7.0"
gem "resque-pool", "~> 0.7.1"

# Assets
gem "propshaft", "~> 1.2.1"
gem "importmap-rails", "~> 2.2.2"

# Hotwire
gem "turbo-rails", "~> 2.0.16"
gem "stimulus-rails"

# Media handling
gem "image_processing", ">= 1.2"

# Telemetry
gem "sentry-ruby"
gem "sentry-rails"

# Other
gem "bcrypt"
gem "web-push"
gem "rqrcode"
gem "rails_autolink"
gem "geared_pagination"
gem "jbuilder"
gem "net-http-persistent"
gem "kredis"
gem "platform_agent"
gem "thruster"
gem "redcarpet"

group :development, :test do
  gem "dotenv-rails"
  gem "debug"
  gem "rubocop-rails-omakase", require: false
  gem "faker", require: false
  gem "brakeman", require: false
end

group :test do
  gem "capybara"
  gem "mocha"
  gem "selenium-webdriver"
  gem "webmock", require: false
end
