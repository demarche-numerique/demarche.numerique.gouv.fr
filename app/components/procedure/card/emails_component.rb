# frozen_string_literal: true

class Procedure::Card::EmailsComponent < ApplicationComponent
  CUSTOMIZABLE_COUNT = 6

  def initialize(procedure:)
    @procedure = procedure
  end

  def customized_progress
    "#{customized_count} / #{CUSTOMIZABLE_COUNT}"
  end

  def customized?
    customized_count.positive?
  end

  private

  def badge
    if error_messages.present?
      { label: t('.badge.error'), variant: :warning }
    elsif customized?
      { label: t('.badge.customized'), variant: :info, icon: false }
    else
      { label: t('.badge.default') }
    end
  end

  def error_messages
    [
      @procedure.errors.messages_for(:email_depose),
      @procedure.errors.messages_for(:email_passe_en_instruction),
      @procedure.errors.messages_for(:email_accepte),
      @procedure.errors.messages_for(:email_refuse),
      @procedure.errors.messages_for(:email_classe_sans_suite),
      @procedure.errors.messages_for(:email_repasse_en_instruction),
    ].flatten.to_sentence
  end

  def customized_count
    [
      @procedure.email_depose,
      @procedure.email_passe_en_instruction,
      @procedure.email_accepte,
      @procedure.email_refuse,
      @procedure.email_classe_sans_suite,
      @procedure.email_repasse_en_instruction,
    ].compact.size
  end
end
