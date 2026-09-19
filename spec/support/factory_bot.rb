# frozen_string_literal: true

module FactoryBot
  module RevisionHelpers
    # Laying a type de champ on a revision by hand goes around its edits: the
    # revision has to read its types de champ again, and its tree has to follow
    # once stored, by a publication or an edit.
    def restore_type_de_champ_tree(revision)
      return if revision.new_record?

      if revision.read_attribute(:type_de_champ_tree).present?
        revision.store_type_de_champ_tree
      else
        revision.reload
      end
    end
  end

  SyntaxRunner.include(RevisionHelpers)
end

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
end
