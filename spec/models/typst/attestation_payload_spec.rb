# frozen_string_literal: true

describe Typst::AttestationPayload do
  let(:dossier) { dossiers.accepte }
  let(:procedure) { dossier.procedure }
  let(:attestation_template) { create(:attestation_template, :v2, :with_files, procedure:, label_direction: "Direction des specs\nBureau des PDF", footer: 'Ministère des specs – 1 rue de la Paix') }

  def payload_for(template, **)
    TypstService.with_assets { described_class.new(template, assets: it, **).to_h }
  end

  it 'is named after its template' do
    expect(described_class.template).to eq('attestation')
    expect(TypstService::ROOT.join('attestation.typ')).to be_file
  end

  describe 'a dossier attestation' do
    subject(:payload) { payload_for(attestation_template, dossier:) }

    it 'pins French and names the document after its title, mentions resolved' do
      I18n.with_locale(:en) do
        expect(payload[:lang]).to eq('fr')
      end
      expect(payload[:title]).to eq("Mon titre pour #{procedure.libelle}")
    end

    it 'carries the letterhead the administration chose' do
      expect(payload).to include(
        official_layout: true,
        intitule: ['Ministère des devs'],
        direction: ['Direction des specs', 'Bureau des PDF'],
        footer: ['Ministère des specs – 1 rue de la Paix']
      )
    end

    it 'embeds the logo and the signature as assets with their alt texts' do
      expect(payload[:logo]).to eq(path: '/assets/1.png', alt: 'Ministère des devs')
      expect(payload[:signature]).to eq(path: '/assets/2.png', alt: 'Signature')
    end

    it 'lays the body out with the dossier values in place of the mentions' do
      expect(payload[:body].map { it[:type] }).to eq(['heading', 'paragraph', 'paragraph'])
      expect(payload[:body].first).to include(level: 1, align: 'center')
      expect(Typst::Tiptap.plain(payload[:body].second[:content])).to eq("Dossier: n° #{dossier.id}")
      expect(Typst::Tiptap.plain(payload[:body].third[:content])).to eq("Déposé le : #{dossier.depose_at.strftime('%d/%m/%Y')}")
    end

    it 'stamps the signature of the dossier groupe instructeur when it has one' do
      attestation_template.signature.purge
      dossier.groupe_instructeur.signature.attach(io: Rails.root.join('spec/fixtures/files/black.png').open, filename: 'black.png', content_type: 'image/png')

      expect(payload[:signature]).to eq(path: '/assets/2.png', alt: 'Signature')
    end
  end

  describe 'a preview' do
    it 'shows the mentions as placeholders without a dossier' do
      payload = payload_for(attestation_template)

      expect(payload[:title]).to eq('Mon titre pour --dossier_procedure_libelle--')
      expect(Typst::Tiptap.plain(payload[:body].second[:content])).to eq('Dossier: n° --dossier_number--')
    end

    it 'stamps the signature of the given groupe instructeur' do
      groupe_instructeur = procedure.defaut_groupe_instructeur
      groupe_instructeur.signature.attach(io: Rails.root.join('spec/fixtures/files/black.png').open, filename: 'black.png', content_type: 'image/png')
      attestation_template.signature.purge

      expect(payload_for(attestation_template, groupe_instructeur:)[:signature]).to eq(path: '/assets/2.png', alt: 'Signature')
    end
  end

  describe 'a template left bare' do
    let(:attestation_template) { create(:attestation_template, :v2, procedure:, label_logo: nil, footer: nil, official_layout: false, json_body: { 'type' => 'doc', 'content' => [{ 'type' => 'title', 'content' => [] }, { 'type' => 'paragraph', 'content' => [{ 'type' => 'text', 'text' => 'Corps' }] }] }) }

    subject(:payload) { payload_for(attestation_template, dossier:) }

    it 'names the document after the kind of decision when the title is blank' do
      expect(payload[:title]).to eq('Attestation d’acceptation')
      expect(payload[:body].map { it[:type] }).to eq(['paragraph'])
    end

    it 'names a refusal accordingly' do
      attestation_template.update!(kind: 'refus')

      expect(payload[:title]).to eq('Attestation de refus')
    end

    it 'falls back to the placeholder name and alt text, without images' do
      expect(payload).to include(official_layout: false, intitule: ['INTITULE de', 'VOTRE INSTITUTION'], direction: [], footer: [], logo: nil, signature: nil)
    end
  end

  it 'sanitizes the authored text for the fonts' do
    attestation_template.update!(footer: "Tabulation\tet emoji\u{1F642}")

    expect(payload_for(attestation_template)[:footer]).to eq(['Tabulation et emoji'])
  end
end
