class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :load_sidebar_data

  private

  def load_sidebar_data
    @sidebar_pinned_memories = Memory.pinned
    @sidebar_total_memories_count = Memory.count
  end
end
