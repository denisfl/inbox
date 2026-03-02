# frozen_string_literal: true

require 'capybara/rspec'
require 'selenium-webdriver'

# Register headless Chrome driver with CI-compatible options
Capybara.register_driver :headless_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new

  options.add_argument('--headless=new')
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--disable-gpu')
  options.add_argument('--window-size=1400,1400')

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

# Use headless Chrome for all JS system tests
Capybara.javascript_driver = :headless_chrome

# Default max wait time for Capybara finders
Capybara.default_max_wait_time = 5

# Server settings
Capybara.server = :puma, { Silent: true }
