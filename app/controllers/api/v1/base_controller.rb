module Api
  module V1
    class BaseController < ActionController::API
      include Rails.application.routes.url_helpers

      rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
      rescue_from ActionController::ParameterMissing, with: :parameter_missing
      rescue_from ActiveRecord::RecordInvalid, with: :record_invalid

      protected

      def render_error(message, status: :bad_request, details: [])
        render json: {
          error: message,
          details: Array(details)
        }, status: status
      end

      def record_not_found(exception)
        render_error("Resource not found", status: :not_found, details: [ exception.message ])
      end

      def parameter_missing(exception)
        render_error("Parameter missing", status: :bad_request, details: [ exception.message ])
      end

      def record_invalid(exception)
        render_error("Validation failed", status: :unprocessable_entity, details: exception.record.errors.full_messages)
      end

      def paginate_scope(scope, default_limit: 50, max_limit: 100)
        limit = (params[:limit].presence || default_limit).to_i
        limit = max_limit if limit > max_limit || limit <= 0
        offset = [ params[:offset].to_i, 0 ].max

        [ scope.offset(offset).limit(limit), { limit: limit, offset: offset, total_count: scope.count } ]
      end

      def memory_json(memory, include_body: true, render_markdown: false, include_attachments: false)
        data = {
          id: memory.id,
          title: memory.title,
          pinned: memory.pinned?,
          pinned_position: memory.pinned_position,
          attachments_count: memory.files.count,
          created_at: memory.created_at&.iso8601,
          updated_at: memory.updated_at&.iso8601
        }

        data[:body] = memory.body if include_body

        if render_markdown
          data[:rendered_html] = MarkdownRenderer.render(memory.body)
        end

        if include_attachments
          data[:attachments] = memory.files.map { |file| attachment_json(file) }
        end

        data
      end

      def attachment_json(attachment)
        url = begin
          rails_blob_url(attachment, only_path: false)
        rescue StandardError
          "/rails/active_storage/blobs/redirect/#{attachment.signed_id}/#{ERB::Util.url_encode(attachment.filename.to_s)}"
        end

        {
          id: attachment.id,
          filename: attachment.filename.to_s,
          content_type: attachment.content_type,
          byte_size: attachment.byte_size,
          created_at: attachment.created_at&.iso8601,
          url: url
        }
      end
    end
  end
end
