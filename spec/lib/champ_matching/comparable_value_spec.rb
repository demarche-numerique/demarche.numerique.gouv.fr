# frozen_string_literal: true

require 'rails_helper'

describe ChampMatching::ComparableValue do
  def comparable(type_champ, **) = described_class.call(namespace: described_class::COMPARISON_NAMESPACES[type_champ], **)
  def namespace(champ_type) = described_class::CHAMP_TYPES[champ_type]

  describe 'CHAMP_TYPES' do
    it 'groups the three free text types, so a textarea can match a text champ' do
      expect(namespace('Champs::TextChamp')).to eq(:text)
      expect(namespace('Champs::TextareaChamp')).to eq(:text)
      expect(namespace('Champs::FormattedChamp')).to eq(:text)
    end

    it 'groups date and datetime, which the truncation to the day makes comparable' do
      expect(namespace('Champs::DateChamp')).to eq(:date)
      expect(namespace('Champs::DatetimeChamp')).to eq(:date)
    end

    it 'keeps one namespace per referentiel, so a SIRET never meets a commune' do
      expect(namespace('Champs::SiretChamp')).to eq(:siret)
      expect(namespace('Champs::CommuneChamp')).to eq(:communes)
    end

    it 'ignores a type that carries no comparable value' do
      expect(namespace('Champs::YesNoChamp')).to be_nil
    end

    # Les clés sont dérivées par transformation de chaîne : un type renommé
    # produirait sans bruit une classe qui n'existe pas, et le champ cesserait
    # d'être comparé sans que rien ne le signale.
    it 'maps every type onto a champ class that exists' do
      expect(described_class::CHAMP_TYPES.keys).to all(satisfy { it.safe_constantize.present? })
      expect(described_class::CHAMP_TYPES.size).to eq(described_class::TYPE_CHAMPS.size)
    end
  end

  # Le cas qui justifie les espaces de comparaison : les deux valeurs se
  # normalisent en la même chaîne, et seule la séparation des espaces empêche de
  # les apparier.
  it 'normalizes a phone and a text champ to the very same string' do
    expect(comparable('phone', value: '0612345678')).to eq('0612345678')
    expect(comparable('text', value: '0612345678')).to eq('0612345678')
    expect(namespace('Champs::PhoneChamp'))
      .not_to eq(namespace('Champs::TextChamp'))
  end

  it 'is nil for a type outside the whitelist, whatever it holds' do
    expect(comparable('yes_no', value: 'true')).to be_nil
    expect(comparable('drop_down_list', value: 'Monsieur')).to be_nil
  end

  describe 'free text' do
    it 'reconciles case, accents, punctuation and spacing' do
      expect(comparable('text', value: "  12 Rue de l'Église ")).to eq('12 rue de l eglise')
      expect(comparable('textarea', value: '12 RUE DE L EGLISE')).to eq('12 rue de l eglise')
    end

    it 'drops a value too short to identify anybody' do
      expect(comparable('text', value: 'ok')).to be_nil
    end

    it 'drops an answer that only says "nothing to declare"' do
      expect(comparable('text', value: 'Néant')).to be_nil
      expect(comparable('text', value: 'Sans objet')).to be_nil
    end
  end

  describe 'typed normalization' do
    it 'reconciles the international and the national phone form' do
      expect(comparable('phone', value: '+33 6 12 34 56 78')).to eq('0612345678')
      expect(comparable('phone', value: '06.12.34.56.78')).to eq('0612345678')
    end

    it 'drops a phone number too short to be one' do
      expect(comparable('phone', value: '01 23')).to be_nil
    end

    it 'reconciles an IBAN whatever its spacing and case' do
      expect(comparable('iban', value: 'fr76 3000 6000 0112 3456 7890 189'))
        .to eq('FR7630006000011234567890189')
    end

    it 'truncates a datetime to the day, so it meets a date champ' do
      expect(comparable('datetime', value: '2026-01-01T09:30:00')).to eq('2026-01-01')
      expect(comparable('date', value: '2026-01-01')).to eq('2026-01-01')
    end

    it 'compares a referentiel on its external id, never on the libelle it resolved to' do
      expect(comparable('siret', value: 'ACME SAS', external_id: ' 41816609600069 '))
        .to eq('41816609600069')
    end

    it 'is nil for a referentiel champ whose lookup never resolved' do
      expect(comparable('rna', value: 'Les Amis du Pont')).to be_nil
    end
  end

  describe 'address' do
    let(:ban) { { 'postal_code' => '75011', 'city_code' => '75056', 'street_address' => '12 rue du Pont' } }

    it 'reconciles two inputs sharing the BAN codes and the street' do
      expect(comparable('address', value_json: ban)).to eq('75011|75056|12 rue du pont')
      expect(comparable('address', value_json: ban.merge('street_address' => '12, Rue du Pont')))
        .to eq('75011|75056|12 rue du pont')
    end

    # Le repli sur le texte libre la rendrait comparable à un champ texte, donc
    # hors de son espace.
    it 'is not comparable at all without a usable value_json' do
      expect(comparable('address', value: '12 rue du Pont')).to be_nil
      expect(comparable('address', value: '12 rue du Pont', value_json: {})).to be_nil
      expect(comparable('address', value_json: { 'street_address' => '12 rue du Pont' })).to be_nil
    end
  end
end
