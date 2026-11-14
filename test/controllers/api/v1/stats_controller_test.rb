require "test_helper"

class Api::V1::StatsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Memory.create!(title: "Memory 1", body: "Text")
    Memory.create!(title: "Memory 2", body: "Text")
    Memory.create!(title: "Pinned Memory", body: "Text", pinned: true, pinned_position: 1)
  end

  test "GET /api/v1/stats returns platform statistics" do
    get api_v1_stats_url, as: :json
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal 3, json["total_memories"]
    assert_equal 1, json["pinned_memories"]
    assert_equal 0, json["total_attachments"]
  end
end
