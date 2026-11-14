require "test_helper"

class MemoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @memory = Memory.create!(title: "Memory A", body: "# Memory Body")
  end

  test "should get index" do
    get memories_url
    assert_response :success
    assert_select "h1", text: /All Memories/
    assert_select "a", text: @memory.title
  end

  test "should search memories" do
    m2 = Memory.create!(title: "Unique Search Title", body: "Something else")
    get memories_url(q: "Unique")
    assert_response :success
    assert_select "a", text: m2.title
    assert_select "a", text: @memory.title, count: 0
  end

  test "should get show with rendered markdown" do
    get memory_url(@memory)
    assert_response :success
    assert_select "h1", text: @memory.title
    assert_select "#rendered_markdown_container h1", text: "Memory Body"
  end

  test "should get new" do
    get new_memory_url
    assert_response :success
  end

  test "should create memory" do
    assert_difference("Memory.count") do
      post memories_url, params: { memory: { title: "New Memory", body: "Sample body" } }
    end

    new_mem = Memory.last
    assert_redirected_to memory_url(new_mem)
  end

  test "should update memory via HTML" do
    patch memory_url(@memory), params: { memory: { title: "Renamed Title", body: "Updated **markdown**" } }
    assert_redirected_to memory_url(@memory)
    assert_equal "Renamed Title", @memory.reload.title
  end

  test "should update memory via JSON for auto-save" do
    patch memory_url(@memory, format: :json), params: { memory: { body: "Auto-saved content" } }
    assert_response :ok
    assert_equal "Auto-saved content", @memory.reload.body
  end

  test "should attach files via ActiveStorage endpoint" do
    FileUtils.mkdir_p(Rails.root.join("test/fixtures/files"))
    File.write(Rails.root.join("test/fixtures/files/sample.txt"), "Sample memory attachment content")
    file = fixture_file_upload("sample.txt", "text/plain")

    assert_difference("@memory.files.count", 1) do
      post attach_files_memory_url(@memory), params: { files: [ file ] }
    end

    assert_redirected_to memory_url(@memory)
    assert_equal "sample.txt", @memory.files.last.filename.to_s
  end

  test "should purge attachment" do
    FileUtils.mkdir_p(Rails.root.join("test/fixtures/files"))
    File.write(Rails.root.join("test/fixtures/files/sample.txt"), "Sample memory attachment content")
    file = fixture_file_upload("sample.txt", "text/plain")
    @memory.files.attach(file)
    attachment = @memory.files.last

    assert_difference("@memory.files.count", -1) do
      delete attachment_memory_url(@memory, attachment.id)
    end

    assert_redirected_to memory_url(@memory)
  end

  test "should destroy memory" do
    assert_difference("Memory.count", -1) do
      delete memory_url(@memory)
    end

    assert_redirected_to root_url
  end

  test "should toggle pin for memory" do
    assert_not @memory.pinned?
    patch toggle_pin_memory_url(@memory)
    assert_redirected_to memory_url(@memory)
    assert @memory.reload.pinned?

    patch toggle_pin_memory_url(@memory, format: :json)
    assert_response :ok
    assert_not @memory.reload.pinned?
  end

  test "should reorder pinned memories" do
    m1 = Memory.create!(title: "M1", pinned: true, pinned_position: 1)
    m2 = Memory.create!(title: "M2", pinned: true, pinned_position: 2)

    patch reorder_pinned_memories_url(format: :json), params: { memory_ids: [ m2.id, m1.id ] }
    assert_response :ok

    assert_equal 1, m2.reload.pinned_position
    assert_equal 2, m1.reload.pinned_position
  end

  test "sidebar displays All Memories and Pinned Memories" do
    @memory.toggle_pin!
    get memories_url
    assert_response :success

    assert_select "nav a[href=?]", memories_path, text: /All Memories/
    assert_select "span", text: "Pinned Memories"
    assert_select "[data-controller='pinned-sortable'] a", text: @memory.title
  end

  test "should generate embedding via generate_embedding action" do
    fake_vector = Array.new(1024) { 0.1 }
    singleton = Llm::EmbeddingGenerator.singleton_class
    original = Llm::EmbeddingGenerator.method(:call)
    singleton.define_method(:call) do |_text, **_kwargs|
      { vector: fake_vector, model: "qwen3-embedding:0.6b" }
    end

    begin
      post generate_embedding_memory_url(@memory)
      assert_redirected_to memory_url(@memory)
      assert_equal "Vector embedding generated successfully (qwen3-embedding:0.6b).", flash[:notice]
      assert @memory.reload.embedded?
    ensure
      singleton.define_method(:call, original)
    end
  end

  test "show displays semantically related memories when embedded" do
    v1 = Array.new(1024, 0.0)
    v1[0] = 1.0

    v2 = Array.new(1024, 0.0)
    v2[0] = 0.95

    @memory.update!(embedding: v1, embedding_model: "qwen3-embedding:0.6b", embedded_at: Time.current)
    neighbor = Memory.create!(title: "Semantically Related Note", body: "Related details", embedding: v2, embedding_model: "qwen3-embedding:0.6b", embedded_at: Time.current)

    get memory_url(@memory)
    assert_response :success
    assert_select "h3", text: /Semantically Related Memories/
    assert_select "a", text: neighbor.title
  end
end
