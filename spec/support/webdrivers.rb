require "selenium/webdriver"

# # Set chromedriver version based on Ruby version to ensure CI compatibility
# if RUBY_VERSION.start_with?('3.0') || RUBY_VERSION.start_with?('3.1')
#   # For Ruby 3.0 and 3.1, use a specific compatible version
#   Webdrivers::Chromedriver.required_version = "134.0.6998.165"
# end
# # Ruby 2.7 seems to work with the default mechanism

Capybara.register_driver :chrome do |app|
  Capybara::Selenium::Driver.new(app, browser: :chrome)
end

Capybara.register_driver :headless_chrome do |app|
  options = ::Selenium::WebDriver::Chrome::Options.new
  options.headless!
  options.add_argument "--window-size=1680,1050"
  options.add_argument "--disable-gpu"
  options.add_argument "--disable-dev-shm-usage"
  options.add_argument "--no-sandbox"

  Capybara::Selenium::Driver.new(
    app,
    browser: :chrome,
    capabilities: [options],
  )
end

Capybara.javascript_driver = :headless_chrome
Capybara.server = :webrick

RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :rack_test
  end

  config.before(:each, type: :system, js: true) do
    driven_by Capybara.javascript_driver
  end
end
