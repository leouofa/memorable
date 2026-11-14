# frozen_string_literal: true

module Api
  module V1
    class MemoriesController < BaseController
      before_action :set_memory, only: %i[show update destroy toggle_pin neighbors generate_embedding]

      def index
        scope = Memory.all

        if params[:pinned].present?
          scope = params[:pinned].to_s == "true" ? scope.where(pinned: true) : scope.where(pinned: false)
        end

        search_mode = params[:mode].presence || "auto"

        if params[:q].present?
          if (search_mode == "semantic" || search_mode == "auto") && scope.embedded.exists?
            begin
              embedding_res = Llm::EmbeddingGenerator.call(params[:q])
              scope = scope.embedded.nearest_neighbors(:embedding, embedding_res[:vector], distance: "cosine")
            rescue StandardError => e
              raise e if search_mode == "semantic"
              scope = scope.search(params[:q])
              scope = params[:pinned].to_s == "true" ? scope.pinned : scope.recent
            end
          else
            scope = scope.search(params[:q])
            scope = params[:pinned].to_s == "true" ? scope.pinned : scope.recent
          end
        else
          scope = params[:pinned].to_s == "true" ? scope.pinned : scope.recent
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

      def neighbors
        limit = (params[:limit].presence || 10).to_i.clamp(1, 100)
        unless @memory.embedded?
          return render_error("Memory has not been embedded yet", status: :unprocessable_entity)
        end

        neighbors = Memory.where.not(id: @memory.id)
                          .embedded
                          .nearest_neighbors(:embedding, @memory.embedding, distance: "cosine")
                          .limit(limit)

        render json: {
          status: "ok",
          memory: memory_json(@memory),
          neighbors: neighbors.map do |neighbor|
            {
              score: (1.0 - neighbor.try(:neighbor_distance).to_f).round(6),
              memory: memory_json(neighbor, include_body: true)
            }
          end
        }
      end

      def generate_embedding
        if params[:async].to_s == "true"
          GenerateEmbeddingJob.perform_later(@memory.id)
          render json: { status: "ok", message: "Embedding generation enqueued" }
        else
          @memory.generate_embedding!
          render json: {
            status: "ok",
            message: "Embedding generated successfully",
            memory: memory_json(@memory)
          }
        end
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
