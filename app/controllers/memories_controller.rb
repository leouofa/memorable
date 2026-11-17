class MemoriesController < ApplicationController
  before_action :set_memory, only: %i[show edit update destroy toggle_pin attach_files purge_attachment generate_embedding]

  def index
    @scope = params[:scope].presence || "all"
    @mode = params[:mode].presence || "auto"

    base_scope = if params[:pinned].to_s == "true"
      Memory.pinned
    else
      Memory.recent
    end

    @memories = if params[:q].present?
      if (@mode == "semantic" || @mode == "auto") && base_scope.embedded.exists?
        begin
          embedding_res = Llm::EmbeddingGenerator.call(params[:q])
          base_scope.embedded.nearest_neighbors(:embedding, embedding_res[:vector], distance: "cosine")
        rescue StandardError => e
          Rails.logger.warn("[MemoriesController] Semantic search fallback to keyword: #{e.message}")
          base_scope.search(params[:q])
        end
      else
        base_scope.search(params[:q])
      end
    else
      base_scope
    end
  end

  def show
    @neighbors = if @memory.embedded?
      Memory.where.not(id: @memory.id)
            .embedded
            .nearest_neighbors(:embedding, @memory.embedding, distance: "cosine")
            .limit(4)
    else
      []
    end
  end

  def new
    @memory = Memory.new
  end

  def edit
  end

  def create
    @memory = Memory.new(memory_params)

    if @memory.save
      redirect_to @memory, notice: "Memory created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    auto_save = params[:auto_save].to_s == "1" || params[:auto_save].to_s == "true"
    @memory.skip_versioning = auto_save

    if @memory.update(memory_params)
      @memory.record_version_snapshot! unless auto_save

      respond_to do |format|
        format.html { redirect_to @memory, notice: "Memory updated successfully." }
        format.json { render json: { status: :ok, memory: @memory, version_number: @memory.current_version_number } }
        format.turbo_stream
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: { errors: @memory.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @memory.destroy
    redirect_to root_path, notice: "Memory deleted successfully."
  end

  def toggle_pin
    @memory.toggle_pin!

    respond_to do |format|
      format.html { redirect_back_or_to @memory }
      format.json { render json: { status: :ok, pinned: @memory.pinned?, pinned_position: @memory.pinned_position } }
    end
  end

  def reorder_pinned
    memory_ids = params[:memory_ids] || []

    Memory.transaction do
      memory_ids.each_with_index do |id, index|
        Memory.where(id: id, pinned: true).update_all(pinned_position: index + 1)
      end
    end

    respond_to do |format|
      format.json { render json: { status: :ok } }
      format.html { redirect_back_or_to root_path }
    end
  end

  def attach_files
    if params[:files].present?
      @memory.files.attach(params[:files])
    end

    respond_to do |format|
      format.html { redirect_to @memory, notice: "Files attached successfully." }
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "memory_attachments",
          partial: "memories/attachments",
          locals: { memory: @memory }
        )
      end
      format.json { render json: { status: :ok, count: @memory.files.count } }
    end
  end

  def purge_attachment
    attachment = @memory.files.find(params[:attachment_id])
    attachment.purge

    respond_to do |format|
      format.html { redirect_to @memory, notice: "Attachment removed." }
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "memory_attachments",
          partial: "memories/attachments",
          locals: { memory: @memory }
        )
      end
    end
  end

  def generate_embedding
    @memory.generate_embedding!
    redirect_to @memory, notice: "Vector embedding generated successfully (#{@memory.embedding_model})."
  rescue StandardError => e
    redirect_to @memory, alert: "Failed to generate embedding: #{e.message}"
  end

  private

  def set_memory
    @memory = Memory.find(params[:id])
  end

  def memory_params
    params.require(:memory).permit(:title, :body, files: [])
  end
end
