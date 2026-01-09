# frozen_string_literal: true

describe 'instructeurs/dossiers/instruction_button_motivation', type: :view do
  let(:dossier) { create(:dossier, :en_instruction) }

  context 'accepter' do
    subject do
      allow(controller).to receive(:params).and_return(statut: 'a-suivre')
      render(
        'instructeurs/dossiers/instruction_button_motivation',
        dossier: dossier,
        popup_title: 'Accepter le dossier',
        placeholder: 'Expliquez au demandeur pourquoi ce dossier est accepté (facultatif)',
        popup_class: 'accept',
        process_action: 'accepter',
        title: 'Accepter',
        confirm: "Confirmez-vous l’acceptation ce dossier ?"
      )
    end

    context 'without attestation' do
      it { expect(subject).not_to have_link(href: apercu_attestation_instructeur_dossier_path(dossier.procedure, dossier, attestation_kind: 'acceptation')) }
    end

    context 'with an attestation' do
      let(:dossier) { create :dossier, :accepte, :with_attestation_acceptation }

      it 'includes a link to preview the attestation' do
        expect(subject).to have_link(href: apercu_attestation_instructeur_dossier_path(dossier.procedure, dossier, attestation_kind: 'acceptation'))
      end
    end
  end

  context 'refuser' do
    subject do
      allow(controller).to receive(:params).and_return(statut: 'a-suivre')
      render(
        'instructeurs/dossiers/instruction_button_motivation',
        dossier: dossier,
        popup_title: 'Refuser le dossier',
        placeholder: 'Expliquez au demandeur pourquoi ce dossier est refusé (obligatoire)',
        popup_class: 'refuse',
        process_action: 'refuser',
        title: 'Refuser',
        confirm: "Confirmez-vous le refus de ce dossier ?"
      )
    end

    context 'without attestation' do
      it do
        expect(subject).not_to have_link(href: apercu_attestation_instructeur_dossier_path(dossier.procedure, dossier, attestation_kind: 'refus'))
      end
    end

    context 'with an attestation' do
      let(:dossier) { create :dossier, :accepte, :with_attestation_refus }

      it 'includes a link to preview the attestation' do
        expect(subject).to have_link(href: apercu_attestation_instructeur_dossier_path(dossier.procedure, dossier, attestation_kind: 'refus'))
      end
    end
  end
end
