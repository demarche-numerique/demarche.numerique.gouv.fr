# frozen_string_literal: true

class AssignTo < ApplicationRecord
  belongs_to :instructeur, optional: false
  belongs_to :groupe_instructeur, optional: false
  has_one :procedure_presentation, dependent: :destroy
  has_one :procedure, through: :groupe_instructeur

  def procedure_presentation_or_default_and_errors
    errors = reset_procedure_presentation_if_invalid

    if self.procedure_presentation.nil?
      self.procedure_presentation = create_procedure_presentation!
    end

    [self.procedure_presentation, errors]
  end

  private

  def reset_procedure_presentation_if_invalid
    errors = begin
               procedure_presentation.errors if procedure_presentation&.invalid?
             rescue ActiveRecord::RecordNotFound => e
               errors = ActiveModel::Errors.new(self)
               errors.add(:procedure_presentation, e.message)
               errors
             end

    if errors.present?
      Sentry.capture_message(
        "Destroying invalid ProcedurePresentation",
        extra: { procedure_presentation_id: procedure_presentation.id, errors: errors.full_messages }
      )

      begin
        if procedure_presentation.procedure&.admin_default_procedure_presentation_id == procedure_presentation.id
          procedure_presentation.procedure.update!(
            admin_default_procedure_presentation_active: false,
            admin_default_procedure_presentation_id: nil
          )
        end
      rescue ActiveRecord::RecordNotFound
      end

      self.procedure_presentation = nil
    end
    errors
  end
end
