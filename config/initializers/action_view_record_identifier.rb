# frozen_string_literal: true

module ActionView::RecordIdentifier
  alias original_dom_class dom_class
  alias original_record_key_for_dom_id record_key_for_dom_id

  def dom_class(record_or_class, prefix = nil)
    if record_or_class.is_a?(ChampData)
      prefix ? "#{prefix}#{JOIN}champ" : "champ"
    else
      original_dom_class(record_or_class, prefix)
    end
  end

  private

  def record_key_for_dom_id(record)
    if record.is_a?(ChampData)
      record.public_id
    else
      original_record_key_for_dom_id(record)
    end
  end
end
