# frozen_string_literal: true

describe API::V2::McpController, type: :controller do
  let(:admin) { administrateurs.default }
  let(:procedure) do
    create(:procedure, administrateurs: [admin], public_type_de_champs: [
      { type: :integer_number, libelle: 'age' },
      { type: :yes_no, libelle: 'boursier' },
    ])
  end
  let(:write_access) { true }
  let(:bearer) do
    token, bearer = APIToken.generate(admin)
    token.update!(write_access:)
    bearer
  end

  def tdc(libelle) = procedure.draft_revision.reload.type_de_champs.find { it.libelle == libelle }
  def sid(libelle) = tdc(libelle).stable_id.to_s

  def rpc(method, params = {}, id: 1)
    post :create, body: { jsonrpc: '2.0', id:, method:, params: }.compact.to_json, as: :json
  end

  def call_tool(name, arguments = {})
    rpc('tools/call', { name:, arguments: })
    response.parsed_body.dig('result')
  end

  def text(result) = result['content'].first['text']

  before do
    procedure
    request.headers['Authorization'] = "Bearer #{bearer}"
    request.headers['Accept'] = 'application/json, text/event-stream'
  end

  describe 'the protocol' do
    it 'answers initialize with what the server is' do
      rpc('initialize', { protocolVersion: '2025-06-18', capabilities: {}, clientInfo: { name: 'spec', version: '1' } })

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['result']).to include('serverInfo' => hash_including('name' => 'demarche_brouillon'))
      expect(response.parsed_body['result']['capabilities']).to include('tools')
      expect(response.parsed_body['result']['instructions']).to include('lire_demarche')
    end

    it 'accepts a notification without answering it' do
      rpc('notifications/initialized', nil, id: nil)

      expect(response).to have_http_status(:accepted)
      expect(response.body).to be_blank
    end

    it 'lists the tools, with the schema of their arguments' do
      rpc('tools/list')

      tools = response.parsed_body['result']['tools']
      expect(tools.map { it['name'] }).to match_array(['lire_demarche', 'lister_types_de_champ', 'ajouter_champ', 'modifier_champ', 'deplacer_champ', 'supprimer_champ', 'definir_condition'])

      ajouter_champ = tools.find { it['name'] == 'ajouter_champ' }
      expect(ajouter_champ['inputSchema']['required']).to eq(['demarche', 'type', 'libelle'])
      expect(ajouter_champ['inputSchema']['properties']['type']['enum']).to include('text', 'repetition')
    end

    it 'opens no stream' do
      get :stream

      expect(response).to have_http_status(:method_not_allowed)
    end
  end

  describe 'the authentication' do
    it 'requires a token' do
      request.headers['Authorization'] = nil
      rpc('tools/list')

      expect(response).to have_http_status(:unauthorized)
      expect(response.headers['WWW-Authenticate']).to eq('Bearer')
    end

    it 'refuses a token that is not one' do
      request.headers['Authorization'] = 'Bearer nope'
      rpc('tools/list')

      expect(response).to have_http_status(:unauthorized)
    end

    it 'refuses the démarche of another administrateur' do
      other = create(:procedure, administrateurs: [create(:administrateur)], public_type_de_champs: [{ libelle: 'secret' }])

      result = call_tool('lire_demarche', { demarche: other.id })

      expect(result['isError']).to be(true)
      expect(text(result)).to include('n’existe pas ou le jeton utilisé n’y donne pas accès')
      expect(text(result)).not_to include('secret')
    end

    context 'with a read only token' do
      let(:write_access) { false }

      it 'reads' do
        expect(call_tool('lire_demarche', { demarche: procedure.id })['isError']).to be_falsey
      end

      it 'does not write' do
        result = call_tool('ajouter_champ', { demarche: procedure.id, type: 'text', libelle: 'nom' })

        expect(result['isError']).to be(true)
        expect(text(result)).to eq('Le jeton utilisé est configuré seulement en lecture.')
        expect(tdc('nom')).to be_nil
      end
    end
  end

  describe 'the tools' do
    it 'lire_demarche describes the draft' do
      draft = JSON.parse(text(call_tool('lire_demarche', { demarche: procedure.id })))

      expect(draft.keys).to eq(['champs', 'annotations'])
      expect(draft['champs'].map { it['libelle'] }).to eq(['age', 'boursier'])
      expect(draft['champs'].first).to include('stable_id' => sid('age'), 'type_champ' => 'integer_number')
      expect(draft['annotations']).to eq([])
    end

    it 'lister_types_de_champ describes the types and their options' do
      types = JSON.parse(text(call_tool('lister_types_de_champ', { demarche: procedure.id })))

      expect(types.find { it['type_champ'] == 'textarea' }).to include('libelle' => 'Texte long', 'options' => ['character_limit'])
      expect(types.find { it['type_champ'] == 'repetition' }).to include('allowed_in_repetition' => false)
    end

    it 'ajouter_champ adds a champ, with its options' do
      result = call_tool('ajouter_champ', { demarche: procedure.id, type: 'drop_down_list', libelle: 'statut', apres: sid('age'), obligatoire: true, options: { drop_down_options: ['salarié', 'étudiant'] } })

      expect(result['isError']).to be_falsey
      expect(JSON.parse(text(result))).to eq('stable_id' => sid('statut'))
      expect(procedure.draft_revision.reload.public_root_type_de_champs.map(&:libelle)).to eq(['age', 'statut', 'boursier'])
      expect(tdc('statut')).to have_attributes(mandatory: true, drop_down_options: ['salarié', 'étudiant'])
    end

    it 'ajouter_champ says why it refuses' do
      result = call_tool('ajouter_champ', { demarche: procedure.id, type: 'text', libelle: 'nom', options: { character_limit: 10 } })

      expect(result['isError']).to be(true)
      expect(text(result)).to include('Options inconnues pour le type « text »')
    end

    it 'modifier_champ updates a champ' do
      result = call_tool('modifier_champ', { demarche: procedure.id, stable_id: sid('age'), libelle: 'âge', obligatoire: false })

      expect(result['isError']).to be_falsey
      expect(tdc('âge')).not_to be_mandatory
    end

    it 'deplacer_champ moves a champ' do
      call_tool('deplacer_champ', { demarche: procedure.id, stable_id: sid('age'), apres: sid('boursier') })

      expect(procedure.draft_revision.reload.public_root_type_de_champs.map(&:libelle)).to eq(['boursier', 'age'])
    end

    it 'definir_condition sets a condition, that lire_demarche reads back' do
      terms = [{ source_stable_id: sid('age'), operator: 'less_than', value: '26' }]

      expect(call_tool('definir_condition', { demarche: procedure.id, stable_id: sid('boursier'), terms: })['isError']).to be_falsey
      expect(tdc('boursier').condition).to eq(Logic::LessThan.new(Logic::ChampValue.new(tdc('age').stable_id), Logic::Constant.new(26)))

      boursier = JSON.parse(text(call_tool('lire_demarche', { demarche: procedure.id })))['champs'].find { it['libelle'] == 'boursier' }
      expect(boursier['condition']).to eq('operator' => 'and', 'terms' => [{ 'source_stable_id' => sid('age'), 'source_libelle' => 'age', 'operator' => 'less_than', 'value' => '26' }])
    end

    it 'supprimer_champ removes a champ, unless a condition reads it' do
      call_tool('definir_condition', { demarche: procedure.id, stable_id: sid('boursier'), terms: [{ source_stable_id: sid('age'), operator: 'less_than', value: '26' }] })

      expect(call_tool('supprimer_champ', { demarche: procedure.id, stable_id: sid('age') })['isError']).to be(true)
      expect(call_tool('supprimer_champ', { demarche: procedure.id, stable_id: sid('boursier') })['isError']).to be_falsey
      expect(procedure.draft_revision.reload.public_root_type_de_champs.map(&:libelle)).to eq(['age'])
    end

    it 'refuses arguments the schema of the tool does not allow' do
      result = call_tool('ajouter_champ', { demarche: procedure.id, type: 'formule', libelle: 'total' })

      expect(result['isError']).to be(true)
      expect(tdc('total')).to be_nil
    end
  end
end
