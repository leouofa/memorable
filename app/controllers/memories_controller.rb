class MemoriesController < ApplicationController
  before_action :set_memory, only: %i[show edit update destroy toggle_pin attach_files purge_attachment]

  def index
    @scope = params[:scope].presence || "all"

    base_scope = if params[:pinned].to_s == "true"
      Memory.pinned
    else
      Memory.recent
    end

    @memories = if params[:q].present?
      base_scope.search(params[:q])
    else
      base_scope
    end
  end

  def show
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
    if @memory.update(memory_params)
      respond_to do |format|
        format.html { redirect_to @memory, notice: "Memory updated successfully." }
        format.json { render json: { status: :ok, memory: @memory } }
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

  private

  def set_memory
    @memory = Memory.find(params[:id])
  end

  def memory_params
    params.require(:memory).permit(:title, :body, files: [])
  end
end
