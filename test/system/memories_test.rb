require "application_system_test_case"

class MemoriesTest < ApplicationSystemTestCase
  setup do
    @memory = Memory.create!(title: "System Test Memory", body: "# Hello World\n\nThis is a system test memory.")
  end

  test "visiting the index and viewing memory" do
    visit root_url
    assert_selector "h1", text: "All Memories"
    assert_text "System Test Memory"

    within "main" do
      click_on "System Test Memory"
    end
    assert_selector "h1", text: "System Test Memory"
    assert_text "Hello World"
  end

  test "creating a new memory" do
    visit root_url
    within "main" do
      click_on "New Memory"
    end

    fill_in "Memory Title", with: "Created via System Test"
    fill_in "Markdown Content", with: "System test body content"
    click_on "Create Memory"

    assert_text "Memory created successfully."
    assert_text "Created via System Test"
  end

  test "clicking memory card navigates to memory details" do
    visit root_url
    find(".group.relative", text: "System Test Memory").click
    assert_selector "h1", text: "System Test Memory"
  end

  test "pinning and unpinning a memory from card" do
    visit root_url
    assert_text "No pinned memories yet."

    within "main" do
      click_on "Pin"
    end

    assert_text "Pinned"
    within "aside" do
      assert_text "System Test Memory"
    end

    within "main" do
      click_on "Pinned"
    end

    within "aside" do
      assert_text "No pinned memories yet."
    end
  end

  test "pin, copy, and toolbar buttons have pointer cursor" do
    visit root_url
    assert_equal "pointer", find("button", text: "Pin").native.css_value("cursor")
    assert_equal "pointer", find("button", text: "Copy").native.css_value("cursor")

    within "main" do
      click_on "System Test Memory"
    end
    assert_selector "h1", text: "System Test Memory"

    assert_equal "pointer", find("button", text: "Pin").native.css_value("cursor")
    assert_equal "pointer", find("button", text: "Copy Markdown").native.css_value("cursor")
    assert_equal "pointer", find("[data-markdown-editor-target='previewTab']").native.css_value("cursor")
    assert_equal "pointer", find("[data-markdown-editor-target='editTab']").native.css_value("cursor")
    assert_equal "pointer", find("[data-markdown-editor-target='splitTab']").native.css_value("cursor")
  end
end
