# frozen_string_literal: true

FactoryBot.define do
  factory :email_accepte, class: Emails::Accepte do
    subject { "Subject, voila voila" }
    body { "Blabla ceci est mon body" }
    association :procedure

    factory :email_passe_en_instruction, class: Emails::PasseEnInstruction

    factory :email_refuse, class: Emails::Refuse

    factory :email_repasse_en_instruction, class: Emails::RepasseEnInstruction

    factory :email_classe_sans_suite, class: Emails::ClasseSansSuite

    factory :email_depose, class: Emails::Depose do
      subject { "[demarche.numerique.gouv.fr] Accusé de réception pour votre dossier n° --numéro du dossier--" }
      body { "Votre administration vous confirme la bonne réception de votre dossier n° --numéro du dossier--" }
    end

    factory :email_depose_et_passe_en_instruction, class: Emails::DeposeEtPasseEnInstruction

    factory :email_depose_et_accepte, class: Emails::DeposeEtAccepte
  end
end
