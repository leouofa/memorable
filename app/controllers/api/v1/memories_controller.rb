module Api
  module V1
    class MemoriesController < BaseController
      before_action :set_memory, only: %i[show update destroy toggle_pin]

      def index
        scope = Memory.all

        if params[:pinned].present?
          scope = params[:pinned].to_s == "true" ? scope.where(pinned: true) : scope.where(pinned: false)
        end

        if params[:q].present?
          scope = scope.search(params[:q])
        end

        # Preserve pinned ordering if specifically requested or default recent
        scope = if params[:pinned].to_s == "true"
          scope.pinned
        else
          scope.recent
        end

        paginated_memories, meta = paginate_scope(scope)
        render json: {
          memories: paginated_memories.map { |m| memory_json(m, include_body: true) },
          meta: meta
        }
      end

      def show
        render_md = params[:render_markdown].to_s == "true" || params[:render_markdown].to_s == "1"
        render json: memory_json(@memory, include_body: true, render_markdown: render_md, include_attachments: true)
      end

      def create
        memory = Memory.new(memory_params)

        if memory.save
          render json: memory_json(memory, include_body: true, include_attachments: true), status: :created
        else
          render_error("Validation failed", status: :unprocessable_entity, details: memory.errors.full_messages)
        end
      end

      def update
        if @memory.update(memory_params)
          render_md = params[:render_markdown].to_s == "true" || params[:render_markdown].to_s == "1"
          render json: memory_json(@memory, include_body: true, render_markdown: render_md, include_attachments: true)
        else
          render_error("Validation failed", status: :unprocessable_entity, details: @memory.errors.full_messages)
        end
      end

      def destroy
        @memory.destroy
        render json: { status: "ok", message: "Memory deleted successfully" }
      end

      def toggle_pin
        @memory.toggle_pin!
        render json: {
          status: "ok",
          pinned: @memory.pinned?,
          pinned_position: @memory.pinned_position,
          memory: memory_json(@memory)
        }
      end

      def reorder_pinned
        memory_ids = params[:memory_ids] || []

        Memory.transaction do
          memory_ids.each_with_index do |id, index|
            Memory.where(id: id, pinned: true).update_all(pinned_position: index + 1)
          end
        end

        render json: { status: "ok", message: "Pinned memories reordered successfully" }
      end

      private

      def set_memory
        @memory = Memory.find(params[:id])
      end

      def memory_params
        payload = params[:memory].is_a?(ActionController::Parameters) ? params[:memory] : params
        payload.permit(:title, :body, :pinned, :pinned_position)
      end
    end
  end
end
