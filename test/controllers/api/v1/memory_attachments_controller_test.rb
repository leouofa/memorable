require "test_helper"

module Api
  module V1
    class MemoryAttachmentsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @memory = Memory.create!(title: "Memory with Attachments")
        FileUtils.mkdir_p(Rails.root.join("test/fixtures/files"))
        File.write(Rails.root.join("test/fixtures/files/sample.txt"), "Sample attachment content")
      end

      test "index lists attachments" do
        file = fixture_file_upload("sample.txt", "text/plain")
        @memory.files.attach(file)

        get attachments_api_v1_memory_url(@memory)
        assert_response :success
        json = response.parsed_body
        assert json.key?("attachments")
        assert_equal 1, json["attachments"].size
        assert_equal "sample.txt", json["attachments"].first["filename"]
      end

      test "create uploads file attachment" do
        file = fixture_file_upload("sample.txt", "text/plain")

        assert_difference("@memory.files.count", 1) do
          post attachments_api_v1_memory_url(@memory), params: { files: [ file ] }
        end
        assert_response :created
      end

      test "create with no files returns 400 bad request" do
        post attachments_api_v1_memory_url(@memory), params: {}, as: :json
        assert_response :bad_request
        json = response.parsed_body
        assert_equal "No files provided for attachment", json["error"]
      end

      test "destroy purges file attachment" do
        file = fixture_file_upload("sample.txt", "text/plain")
        @memory.files.attach(file)
        att = @memory.files.last

        assert_difference("@memory.files.count", -1) do
          delete attachment_api_v1_memory_url(@memory, att.id)
        end
        assert_response :success
        json = response.parsed_body
        assert_equal "ok", json["status"]
        assert_equal "Attachment removed successfully", json["message"]
      end
    end
  end
end
