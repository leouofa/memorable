# frozen_string_literal: true

require "application_system_test_case"

class MemoryVersionsTest < ApplicationSystemTestCase
  setup do
    @memory = Memory.create!(title: "Versioned Memory v1", body: "First version content")
    @memory.update!(title: "Versioned Memory v2", body: "Second version content")
  end

  test "viewing version history, inspecting diffs, and restoring a previous version" do
    visit memory_url(@memory)
    assert_text "History (v2)"

    click_on "History (v2)"
    assert_selector "h1", text: "Version History"
    assert_text "2 versions"
    assert_text "+1"
    assert_text "-1"
    assert_text "Second version content"

    # Click on v1 in timeline
    find("#version_item_1").click
    assert_text "First version content"
    assert_button "Restore v1"

    accept_confirm do
      click_on "Restore v1"
    end

    assert_text "Restored memory to v1 (saved as v3)."
    assert_selector "h1", text: "Versioned Memory v1"
    assert_text "History (v3)"
    assert_text "First version content"
  end
end
