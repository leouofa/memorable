# frozen_string_literal: true

require "test_helper"

class MemoryVersionTest < ActiveSupport::TestCase
  test "creating a memory automatically creates initial v1 version" do
    memory = Memory.create!(title: "Initial Title", body: "Initial body content")

    assert_equal 1, memory.versions.count
    assert_equal 1, memory.current_version_number

    v1 = memory.latest_version
    assert_equal 1, v1.version_number
    assert_equal "Initial Title", v1.title
    assert_equal "Initial body content", v1.body
    assert_not memory.unversioned_changes?
  end

  test "updating title or body creates sequential versions" do
    memory = Memory.create!(title: "v1 Title", body: "v1 body")

    memory.update!(body: "v2 body")
    assert_equal 2, memory.versions.count
    assert_equal 2, memory.current_version_number
    assert_equal "v2 body", memory.latest_version.body

    memory.update!(title: "v3 Title")
    assert_equal 3, memory.versions.count
    assert_equal 3, memory.current_version_number
    assert_equal "v3 Title", memory.latest_version.title

    assert_equal [ 3, 2, 1 ], memory.versions.ordered.pluck(:version_number)
  end

  test "updating non-content attributes like pinned does not create a version" do
    memory = Memory.create!(title: "Pin Test", body: "Body content")
    assert_equal 1, memory.versions.count

    memory.toggle_pin!
    assert_equal 1, memory.versions.count
  end

  test "skip_versioning prevents version creation on background auto-save until explicit snapshot" do
    memory = Memory.create!(title: "Draft Memory", body: "Original text")
    assert_equal 1, memory.versions.count

    memory.skip_versioning = true
    memory.update!(body: "Auto-saved draft 1")
    assert_equal 1, memory.versions.count
    assert memory.unversioned_changes?

    memory.skip_versioning = true
    memory.update!(body: "Auto-saved draft 2")
    assert_equal 1, memory.versions.count

    # Explicit save (even with no new column change on this call) snapshots the accumulated draft
    memory.skip_versioning = false
    memory.record_version_snapshot!
    assert_equal 2, memory.versions.count
    assert_equal "Auto-saved draft 2", memory.latest_version.body
    assert_not memory.unversioned_changes?
  end

  test "restore_version! non-destructively restores a previous version as a new version" do
    memory = Memory.create!(title: "Original Title", body: "Line 1")
    v1 = memory.latest_version

    memory.update!(title: "Modified Title", body: "Line 1\nLine 2")
    assert_equal 2, memory.current_version_number

    memory.restore_version!(v1)
    memory.reload

    assert_equal 3, memory.current_version_number
    assert_equal "Original Title", memory.title
    assert_equal "Line 1", memory.body
    assert_equal "Original Title", memory.latest_version.title
    assert_equal "Line 1", memory.latest_version.body
  end

  test "restore_version! preserves unversioned auto-saved changes before restoring" do
    memory = Memory.create!(title: "v1", body: "First")
    v1 = memory.latest_version

    memory.skip_versioning = true
    memory.update!(body: "Unversioned auto-saved work")
    assert_equal 1, memory.versions.count

    memory.restore_version!(v1)
    memory.reload

    # v2 snapshots the unversioned draft, v3 is the restored v1
    assert_equal 3, memory.versions.count
    assert_equal "Unversioned auto-saved work", memory.versions.find_by(version_number: 2).body
    assert_equal "First", memory.versions.find_by(version_number: 3).body
  end
end
