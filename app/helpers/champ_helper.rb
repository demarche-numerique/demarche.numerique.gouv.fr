# frozen_string_literal: true

module ChampHelper
  def format_text_value(text)
    sanitized_text = html_escape(text)
    auto_linked_text = Anchored::Linker.auto_link(sanitized_text, target: '_blank', rel: 'noopener') do |link_href|
      truncate(link_href, length: 60)
    end
    simple_format(auto_linked_text, {}, sanitize: false)
  end

  def auto_attach_url(object, procedure_id: nil)
    if object.is_a?(Champ)
      champs_piece_justificative_url(object.dossier, object.stable_id, row_id: object.row_id)
    elsif object.is_a?(TypeDeChamp) && object.piece_justificative?
      piece_justificative_template_admin_procedure_type_de_champ_url(stable_id: object.stable_id, procedure_id:)
    elsif object.is_a?(TypeDeChamp) && object.explication?
      notice_explicative_admin_procedure_type_de_champ_url(stable_id: object.stable_id, procedure_id:)
    end
  end
end
