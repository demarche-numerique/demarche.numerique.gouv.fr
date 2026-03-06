# frozen_string_literal: true

# Value object for attachment component configuration.
# Eliminates parameter duplication across attachment components.
class Attachment::Context
  attr_reader :champ, :attached_file, :auto_attach_url, :direct_upload, :view_as,
              :user_can_destroy, :form_object_name, :aria_labelledby,
              :parent_hint_id

  alias user_can_destroy? user_can_destroy

  def initialize(
    champ: nil,
    attached_file: nil,
    auto_attach_url: nil,
    direct_upload: true,
    view_as: :link,
    user_can_destroy: true,
    form_object_name: nil,
    aria_labelledby: nil,
    parent_hint_id: nil
  )
    @champ = champ
    @attached_file = attached_file || champ&.piece_justificative_file
    @auto_attach_url = auto_attach_url
    @direct_upload = direct_upload
    @view_as = view_as
    @user_can_destroy = user_can_destroy
    @form_object_name = form_object_name
    @aria_labelledby = aria_labelledby
    @parent_hint_id = parent_hint_id

    validate!
  end

  def downloadable?
    view_as == :download
  end

  def for_champ?
    champ.present?
  end

  private

  def validate!
    unless [:download, :link].include?(@view_as)
      raise ArgumentError, "Invalid view_as: #{@view_as}, must be :download or :link"
    end
  end
end
