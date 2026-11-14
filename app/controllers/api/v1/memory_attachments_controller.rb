module Api
  module V1
    class MemoryAttachmentsController < BaseController
      before_action :set_memory

      def index
        render json: {
          attachments: @memory.files.map { |file| attachment_json(file) }
        }
      end

      def create
        if params[:files].blank?
          return render_error("No files provided for attachment", status: :bad_request)
        end

        @memory.files.attach(params[:files])

        render json: {
          status: "ok",
          attachments: @memory.files.map { |file| attachment_json(file) }
        }, status: :created
      end

      def destroy
        attachment = @memory.files.find(params[:attachment_id])
        attachment.purge

        render json: {
          status: "ok",
          message: "Attachment removed successfully"
        }
      end

      private

      def set_memory
        @memory = Memory.find(params[:id])
      end
    end
  end
end
