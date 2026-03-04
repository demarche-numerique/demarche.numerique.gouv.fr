# frozen_string_literal: true

# Displays upload hints: max file size, allowed formats, identity document requirements.
# Centralizes validation rules presentation.
class Attachment::HintsComponent < ApplicationComponent
  delegate :max_file_size, :allowed_extensions, to: :validation

  def initialize(champ:, attached_file: nil, show_identity_hint: false, html_id: nil)
    @champ = champ
    @attached_file = attached_file
    @show_identity_hint = show_identity_hint
    @html_id = html_id
  end

  def validation
    @validation ||= Attachment::Validation.new(attached_file: @attached_file)
  end

  def show_identity_hint?
    @show_identity_hint && @champ&.titre_identite_nature?
  end

  def render?
    max_file_size.present? || allowed_extensions.present? || show_identity_hint?
  end
end
