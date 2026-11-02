# frozen_string_literal: true

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  # Matches any character that is a control character in ASCII :
  # \x00-\x08: Matches control characters from NULL (0) through BACKSPACE (8)
  # \x0B: Matches VERTICAL TAB (11)
  # \x0E-\x1F: Matches control characters from SHIFT OUT (14) through UNIT SEPARATOR (31)
  # \x7F: Matches DELETE (127)
  #
  # Except a few specific ones :
  # \x09: HORIZONTAL TAB
  # \x0A: LINE FEED
  # \x0D: CARRIAGE RETURN
  NON_PRINTABLE_REGEXP = /[\x00-\x08\x0B\x0E-\x1F\x7F]/.freeze

  # we want to replace line feed with a \n
  LINE_FEED_REGEXP = /\x0A/.freeze

  # In practical terms, this regular expression is used to remove non-printable control characters from some user inputs
  NORMALIZES_NON_PRINTABLE_PROC = -> (attr) do
    attr.gsub(NON_PRINTABLE_REGEXP, '').gsub(LINE_FEED_REGEXP, "\n")
  end

  # Models the GraphQL API v2 resolves from a client-supplied global id (`loads:` arguments),
  # besides Dossier which is scoped to what the administration may see.
  TYPED_ID_MODELS = ['Commentaire', 'GroupeInstructeur', 'Instructeur', 'Label', 'Webhook'].freeze

  def self.record_from_typed_id(id)
    class_name, record_id = GraphQL::Schema::UniqueWithinType.decode(id)

    if class_name == 'Dossier'
      Dossier.visible_by_administration.find(record_id)
    elsif class_name.in?(TYPED_ID_MODELS)
      Object.const_get(class_name).find(record_id)
    else
      raise ActiveRecord::RecordNotFound, "Unexpected object: #{class_name}"
    end
  rescue => e
    raise ActiveRecord::RecordNotFound, e.message
  end

  def self.id_from_typed_id(id)
    GraphQL::Schema::UniqueWithinType.decode(id)[1]
  end

  def self.stable_id_from_typed_id(prefixed_typed_id)
    return nil unless prefixed_typed_id.starts_with?("champ_")

    self.id_from_typed_id(prefixed_typed_id.gsub("champ_", "")).to_i
  rescue
    nil
  end

  def to_typed_id
    GraphQL::Schema::UniqueWithinType.encode(self.class.name, id)
  end

  def to_typed_id_for_query
    to_typed_id.delete("==")
  end
end
