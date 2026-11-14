# frozen_string_literal: true

module Api
  module V1
    class SearchController < BaseController
      def index
        query = params[:q].to_s.strip
        return render_error("Query parameter 'q' must not be blank", status: :bad_request) if query.blank?

        mode = params[:mode].presence || "auto"
        limit = (params[:limit].presence || 20).to_i.clamp(1, 100)

        scope = Memory.all

        if (mode == "semantic" || mode == "auto") && scope.embedded.exists?
          begin
            embedding_res = Llm::EmbeddingGenerator.call(query)
            query_vector = embedding_res[:vector]

            results = scope.embedded
                           .nearest_neighbors(:embedding, query_vector, distance: "cosine")
                           .limit(limit)
                           .map do |memory|
                             {
                               type: "Memory",
                               score: (1.0 - memory.try(:neighbor_distance).to_f).round(6),
                               data: memory_json(memory, include_body: true)
                             }
                           end

            return render json: {
              status: "ok",
              results: results,
              meta: { mode: "semantic", query: query, count: results.size }
            }
          rescue StandardError => e
            raise e if mode == "semantic"
            Rails.logger.warn("[Api::V1::SearchController] Semantic search fallback to keyword: #{e.message}")
          end
        end

        # Keyword fallback or mode == "keyword"
        results = scope.search(query)
                       .limit(limit)
                       .map do |memory|
                         {
                           type: "Memory",
                           score: nil,
                           data: memory_json(memory, include_body: true)
                         }
                       end

        render json: {
          status: "ok",
          results: results,
          meta: { mode: "keyword", query: query, count: results.size }
        }
      end
    end
  end
end
