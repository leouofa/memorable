module Api
  module V1
    class StatsController < BaseController
      def show
        render json: {
          total_memories: Memory.count,
          pinned_memories: Memory.where(pinned: true).count,
          total_attachments: ActiveStorage::Attachment.where(record_type: "Memory").count
        }
      end
    end
  end
end
