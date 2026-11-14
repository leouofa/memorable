require "test_helper"

module Api
  module V1
    class MemoriesControllerTest < ActionDispatch::IntegrationTest
      setup do
        @memory = Memory.create!(title: "API Memory", body: "# API Markdown Test")
      end

      test "index lists memories with pagination" do
        get api_v1_memories_url
        assert_response :success
        json = response.parsed_body
        assert json.key?("memories")
        assert json.key?("meta")
        assert_equal 1, json["memories"].size
        assert_equal @memory.title, json["memories"].first["title"]
      end

      test "index filters by search query" do
        Memory.create!(title: "Other Item", body: "irrelevant")
        get api_v1_memories_url(q: "API")
        assert_response :success
        json = response.parsed_body
        assert_equal 1, json["memories"].size
        assert_equal "API Memory", json["memories"].first["title"]
      end

      test "index filters by pinned status" do
        @memory.toggle_pin!
        Memory.create!(title: "Unpinned Memory", body: "none")

        get api_v1_memories_url(pinned: "true")
        assert_response :success
        json = response.parsed_body
        assert_equal 1, json["memories"].size
        assert_equal @memory.id, json["memories"].first["id"]
      end

      test "show returns memory details" do
        get api_v1_memory_url(@memory)
        assert_response :success
        json = response.parsed_body
        assert_equal @memory.id, json["id"]
        assert_equal @memory.title, json["title"]
        assert_equal @memory.body, json["body"]
      end

      test "show renders markdown when requested" do
        get api_v1_memory_url(@memory, render_markdown: "true")
        assert_response :success
        json = response.parsed_body
        assert json.key?("rendered_html")
        assert_includes json["rendered_html"], "API Markdown Test"
      end

      test "create creates memory" do
        assert_difference("Memory.count") do
          post api_v1_memories_url, params: {
            memory: { title: "New JSON Memory", body: "# Content" }
          }, as: :json
        end
        assert_response :created
        json = response.parsed_body
        assert_equal "New JSON Memory", json["title"]
      end

      test "update updates memory" do
        patch api_v1_memory_url(@memory), params: {
          memory: { title: "Updated JSON Memory" }
        }, as: :json
        assert_response :success
        assert_equal "Updated JSON Memory", @memory.reload.title
      end

      test "destroy deletes memory" do
        assert_difference("Memory.count", -1) do
          delete api_v1_memory_url(@memory)
        end
        assert_response :success
      end

      test "toggle_pin toggles pin status" do
        patch toggle_pin_api_v1_memory_url(@memory)
        assert_response :success
        json = response.parsed_body
        assert_equal true, json["pinned"]
        assert @memory.reload.pinned?
      end

      test "reorder_pinned reorders pinned memories" do
        m1 = Memory.create!(title: "M1", pinned: true, pinned_position: 1)
        m2 = Memory.create!(title: "M2", pinned: true, pinned_position: 2)

        patch reorder_pinned_api_v1_memories_url, params: {
          memory_ids: [ m2.id, m1.id ]
        }, as: :json
        assert_response :success

        assert_equal 1, m2.reload.pinned_position
        assert_equal 2, m1.reload.pinned_position
      end
    end
  end
end
