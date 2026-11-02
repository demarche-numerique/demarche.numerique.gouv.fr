# frozen_string_literal: true

class ProcedureUserOverlap < ApplicationRecord
  include ChampMatchingConcern

  belongs_to :left_procedure, class_name: 'Procedure', inverse_of: :procedure_user_overlaps_as_left
  belongs_to :right_procedure, class_name: 'Procedure', inverse_of: :procedure_user_overlaps_as_right

  has_many :type_de_champ_matches,
           primary_key: [:left_procedure_id, :right_procedure_id],
           foreign_key: [:left_procedure_id, :right_procedure_id],
           inverse_of: :procedure_user_overlap,
           dependent: :delete_all

  scope :within, -> (procedure_ids) { where(left_procedure_id: procedure_ids, right_procedure_id: procedure_ids) }
  scope :champs_pending, -> { where(champs_computed_at: nil) }
end
