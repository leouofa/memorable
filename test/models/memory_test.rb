require "test_helper"

class MemoryTest < ActiveSupport::TestCase
  test "validates presence of title" do
    memory = Memory.new(title: "")
    assert_not memory.valid?
    assert_includes memory.errors[:title], "can't be blank"

    memory.title = "Valid Title"
    assert memory.valid?
  end

  test "search scope filters by title and body" do
    m1 = Memory.create!(title: "Rails Optimization", body: "Use bullet for N+1 queries")
    m2 = Memory.create!(title: "Python Tips", body: "List comprehensions are fast")

    assert_includes Memory.search("Optimization"), m1
    assert_not_includes Memory.search("Optimization"), m2

    assert_includes Memory.search("bullet"), m1
    assert_not_includes Memory.search("bullet"), m2
  end

  test "toggle_pin! toggles pinned state and manages pinned_position" do
    m1 = Memory.create!(title: "Memory 1")
    m2 = Memory.create!(title: "Memory 2")

    assert_not m1.pinned?
    m1.toggle_pin!
    assert m1.pinned?
    assert_equal 1, m1.pinned_position

    m2.toggle_pin!
    assert m2.pinned?
    assert_equal 2, m2.pinned_position

    assert_equal [ m1, m2 ], Memory.pinned.to_a

    m1.toggle_pin!
    assert_not m1.pinned?
    assert_nil m1.pinned_position
    assert_equal [ m2 ], Memory.pinned.to_a
  end
end
