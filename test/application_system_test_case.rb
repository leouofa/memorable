require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  teardown do
    page.driver.browser.manage.window.resize_to(1400, 1400) rescue nil
    page.execute_script("localStorage.clear(); sessionStorage.clear();") rescue nil
  end
end
