# frozen_string_literal: true

class Expert < ApplicationRecord
  belongs_to :user
  has_many :experts_procedures
  has_many :procedures, through: :experts_procedures
  # Either revocation ends the expert's access to the dossier, so the plain name
  # is the safe one: no caller reaches a revoked avis — or its dossier — by
  # forgetting a filter. Revoked avis stay visible to the instructeur, who reads
  # them through `dossier.avis`.
  has_many :avis, -> { not_revoked }, through: :experts_procedures
  has_many :dossiers, through: :avis
  has_many :commentaires, inverse_of: :expert, dependent: :nullify

  default_scope { eager_load(:user) }

  def email
    user.email
  end

  # A flat set rather than the dossiers association, which joins through avis:
  # DossierSearchService evaluates the relation twice and caps the match set at
  # MAX_RESULTS before de-duplicating, so a join repeating a dossier once per
  # avis would spend that cap on duplicates.
  def dossiers_for_search
    Dossier.where(id: avis.select(:dossier_id))
  end

  def self.by_email(email)
    Expert.eager_load(:user).find_by(users: { email: email })
  end

  def avis_summary
    @avis_summary ||= { unanswered: avis.without_answer.not_hidden_by_administration.not_termine.count }
  end

  def self.autocomplete_mails(procedure)
    # granting_access is a no-op while the procedure lets instructeurs invite
    # whoever they want, so it applies to both modes and the branch below is
    # left to decide only which experts are worth suggesting. A subquery rather
    # than a merge: granting_access joins :procedure, which Expert has no
    # singular association for.
    procedure_experts = Expert
      .joins(:experts_procedures, :user)
      .where(experts_procedures: { procedure: procedure, id: ExpertsProcedure.granting_access })

    suggested_expert = if procedure.experts_require_administrateur_invitation?
      procedure_experts
    else
      procedure_experts
        .where.not(users: { last_sign_in_at: nil })
        .or(procedure_experts.where(users: { created_at: 1.day.ago.. }))
    end

    suggested_expert
      .pluck('users.email')
      .sort
  end

  def merge(old_expert)
    return if old_expert.nil?

    procedure_with_new, procedure_without_new = old_expert
      .procedures
      .with_discarded
      .partition { |p| p.experts.exists?(id) }

    ExpertsProcedure
      .where(expert_id: old_expert.id, procedure: procedure_without_new)
      .update_all(expert_id: id)

    ExpertsProcedure
      .where(expert_id: old_expert.id, procedure: procedure_with_new)
      .find_each do |old_experts_procedure|
        new_experts_procedure = ExpertsProcedure.find_by(expert_id: id, procedure_id: old_experts_procedure.procedure_id)
        old_experts_procedure.avis.update_all(experts_procedure_id: new_experts_procedure.id)
        if old_experts_procedure.revoked_at.nil? && new_experts_procedure.revoked_at.present?
          new_experts_procedure.update(revoked_at: nil)
        end
        old_experts_procedure.destroy
      end

    old_expert.commentaires.update_all(expert_id: id)

    Avis
      .where(claimant_id: old_expert.id, claimant_type: Expert.name)
      .update_all(claimant_id: id)
  end
end
