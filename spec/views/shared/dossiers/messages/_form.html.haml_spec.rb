# frozen_string_literal: true

describe 'shared/dossiers/messages/_form', type: :view do
  let(:dossier) { create(:dossier, :en_construction) }
  let(:commentaire) { Commentaire.new }

  subject(:rendered_form) do
    render partial: 'shared/dossiers/messages/form', locals: { commentaire:, form_url: '/commentaires', dossier:, connected_user: dossier.user }
    rendered
  end

  before do
    allow(view).to receive(:instructeur_signed_in?).and_return(false)
    allow(view).to receive(:administrateur_signed_in?).and_return(false)
    allow(view).to receive(:expert_signed_in?).and_return(false)
  end

  it 'annonce la taille maximale par fichier et la possibilité d’en joindre plusieurs' do
    expect(rendered_form).to include('Taille maximale par fichier : 200 Mo. Plusieurs fichiers possibles')
  end

  it 'expose la limite de taille au contrôle côté client' do
    expect(rendered_form).to include('data-max-file-size="209715200"')
  end

  context 'quand la pièce jointe est en erreur' do
    before { commentaire.errors.add(:piece_jointe, :file_size_not_less_than, max: '200 Mo') }

    it 'affiche le message d’erreur' do
      expect(rendered_form).to include('La taille maximale du fichier autorisée est de 200 Mo.')
    end

    it 'marque le groupe de champ en erreur' do
      expect(rendered_form).to include('fr-input-group--error')
    end
  end
end
