# frozen_string_literal: true

require "test_helper"

class MemoryVersionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @memory = Memory.create!(title: "Architecture v1", body: "# Heading\nInitial line")
    @v1 = @memory.latest_version
    @memory.update!(title: "Architecture v2", body: "# Heading\nUpdated line\nExtra line")
    @v2 = @memory.latest_version
  end

  test "should get versions index and show latest version diff by default" do
    get memory_versions_url(@memory)
    assert_response :success
    assert_select "h1", text: /Version History/
    assert_select "#version_timeline a", count: 2
    assert_select "#version_diff_container", text: /Updated line/
    assert_select "#title_diff_banner", text: /Architecture v1/
  end

  test "should get specific version in diff, rendered, and raw modes" do
    get memory_version_url(@memory, @v1, view: "rendered")
    assert_response :success
    assert_select "#version_rendered_container h1", text: "Heading"

    get memory_version_url(@memory, @v1, view: "raw")
    assert_response :success
    assert_select "#version_raw_container pre", text: /Initial line/
  end

  test "should restore previous version and create a new version" do
    assert_difference("@memory.versions.count", 1) do
      post restore_memory_version_url(@memory, @v1)
    end

    assert_redirected_to memory_url(@memory)
    @memory.reload
    assert_equal 3, @memory.current_version_number
    assert_equal "Architecture v1", @memory.title
    assert_equal "# Heading\nInitial line", @memory.body
  end

  test "background auto_save updates memory without creating a version while explicit update creates a version" do
    assert_no_difference("@memory.versions.count") do
      patch memory_url(@memory, format: :json), params: {
        auto_save: "1",
        memory: { body: "Auto-saved body change" }
      }
    end
    assert_response :ok
    assert_equal "Auto-saved body change", @memory.reload.body

    # Explicit save (auto_save: "0") commits the auto-saved draft as a new version
    assert_difference("@memory.versions.count", 1) do
      patch memory_url(@memory, format: :json), params: {
        auto_save: "0",
        memory: { body: "Auto-saved body change" }
      }
    end
    assert_response :ok
    assert_equal 3, @memory.reload.current_version_number
  end
end
