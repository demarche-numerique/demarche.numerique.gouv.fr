# frozen_string_literal: true

# FIXME: where a type de champ sat in a revision, before the revisions stored
# their tree (ProcedureRevision#type_de_champ_tree). No longer written nor
# read: the rows left go with their revision or their type de champ, until the
# table is dropped (#14009).
class ProcedureRevisionTypeDeChamp < ApplicationRecord
  belongs_to :revision, class_name: 'ProcedureRevision'
  belongs_to :type_de_champ

  belongs_to :parent, class_name: 'ProcedureRevisionTypeDeChamp', optional: true
  has_many :children_revision_type_de_champs, foreign_key: :parent_id, class_name: 'ProcedureRevisionTypeDeChamp', inverse_of: :parent, dependent: :destroy
end
