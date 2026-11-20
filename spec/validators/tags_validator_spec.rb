# frozen_string_literal: true

describe TagsValidator do
  let(:procedure) do
    create(:procedure, :published,
      public_type_de_champs: [
        { type: :header_section, level: 1, libelle: 'h1' },
        { libelle: 'a' },
        { type: :repetition, libelle: 'r', children: [{ libelle: 'r1' }] },
      ],
      private_type_de_champs: [{ libelle: 'c' }])
  end
  let(:administrateur) { procedure.administrateurs.first }
  let(:draft) { procedure.draft_revision }

  def type_de_champ(libelle) = draft.type_de_champs.find { it.libelle == libelle }

  # as read by another request: the procedure memoizes what it reads of its revisions
  def template_naming(*type_de_champs)
    mentions = type_de_champs.map { { type: 'mention', attrs: { id: "tdc#{it.stable_id}", label: it.libelle } } }
    json_body = { type: 'doc', content: [{ type: 'paragraph', content: mentions }] }

    build(:attestation_template, :v2, procedure: Procedure.find(procedure.id), json_body:).tap(&:validate)
  end

  it 'accepts what a revision lays outside any repetition, within a header section or not' do
    expect(template_naming(type_de_champ('a'), type_de_champ('c')).errors[:json_body]).to be_empty
  end

  it 'refuses the content of a repetition' do
    expect(template_naming(type_de_champ('r1')).errors).to be_of_kind(:json_body, :champ_missing_in_published_and_draft_revision)
  end

  it 'refuses a champ the draft adds, until it is published' do
    added = draft.add_type_de_champ(type_champ: :text, libelle: 'added')

    expect(template_naming(added).errors).to be_of_kind(:json_body, :champ_missing_in_published_revision)
  end

  it 'refuses a champ the draft removes' do
    removed = type_de_champ('a')
    draft.remove_type_de_champ(removed.stable_id)

    expect(template_naming(removed).errors).to be_of_kind(:json_body, :champ_missing_in_draft_revision)
  end

  it 'refuses a champ removed and published since' do
    removed = type_de_champ('a')
    draft.remove_type_de_champ(removed.stable_id)
    procedure.publish_revision!(administrateur)

    expect(template_naming(removed).errors).to be_of_kind(:json_body, :champ_missing_in_published_and_draft_revision)
  end

  context 'with dossiers pending on previous revisions' do
    let(:added) { draft.add_type_de_champ(type_champ: :text, libelle: 'added') }

    before do
      create(:dossier, :en_construction, procedure:)
      added
      procedure.publish_revision!(administrateur)
    end

    it 'refuses a champ one of them does not lay out' do
      expect(template_naming(added).errors).to be_of_kind(:json_body, :champ_missing_in_previous_revision)
    end

    it 'lays them out in one query' do
      create(:dossier, :en_construction, procedure:)
      Procedure.find(procedure.id).draft_revision.add_type_de_champ(type_champ: :text, libelle: 'added again')
      Procedure.find(procedure.id).publish_revision!(administrateur)
      procedure = Procedure.find(self.procedure.id)

      queries = []
      callback = lambda { |*args| queries << args.last[:sql] if args.last[:sql].include?('FROM "types_de_champ"') }
      revisions = ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
        procedure.revisions_with_pending_dossiers.each(&:root_type_de_champs)
      end

      expect(revisions.size).to eq(2)
      expect(queries.size).to eq(1)
    end
  end

  it 'takes a revision not saved yet as laying out nothing' do
    template = build(:attestation_template, procedure: build(:procedure))

    expect { template.validate }.not_to raise_error
    expect(template.errors[:body]).to be_empty
  end
end
