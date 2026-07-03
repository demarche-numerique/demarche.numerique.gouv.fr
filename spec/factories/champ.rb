# frozen_string_literal: true

FactoryBot.define do
  factory :champ_do_not_use, class: 'ChampData' do
    type { 'Champs::TextChamp' }
    stream { Dossier::MAIN_STREAM }
    add_attribute(:private) { false }

    factory :champ_do_not_use_text, class: 'ChampData' do
      type { 'Champs::TextChamp' }
      value { 'text' }
    end

    factory :champ_do_not_use_textarea, class: 'ChampData' do
      type { 'Champs::TextareaChamp' }
      value { 'textarea' }
    end

    factory :champ_do_not_use_date, class: 'ChampData' do
      type { 'Champs::DateChamp' }
      value { '2019-07-10' }
    end

    factory :champ_do_not_use_datetime, class: 'ChampData' do
      type { 'Champs::DatetimeChamp' }
      value { '15/09/1962 15:35' }
    end

    factory :champ_do_not_use_number, class: 'ChampData' do
      type { 'Champs::NumberChamp' }
      value { '42' }
    end

    factory :champ_do_not_use_decimal_number, class: 'ChampData' do
      type { 'Champs::DecimalNumberChamp' }
      value { '42.1' }
    end

    factory :champ_do_not_use_integer_number, class: 'ChampData' do
      type { 'Champs::IntegerNumberChamp' }
      value { '42' }
    end

    factory :champ_do_not_use_checkbox, class: 'ChampData' do
      type { 'Champs::CheckboxChamp' }
      value { 'true' }
    end

    factory :champ_do_not_use_civilite, class: 'ChampData' do
      type { 'Champs::CiviliteChamp' }
      value { 'M.' }
    end

    factory :champ_do_not_use_email, class: 'ChampData' do
      type { 'Champs::EmailChamp' }
      value { 'yoda@beta.gouv.fr' }
    end

    factory :champ_do_not_use_phone, class: 'ChampData' do
      type { 'Champs::PhoneChamp' }
      value { '0666666666' }
    end

    factory :champ_do_not_use_address, class: 'ChampData' do
      type { 'Champs::AddressChamp' }
      value { '2 rue des Démarches' }
      value_json do
        {
          type: "housenumber",
          label: "2 rue des Démarches grenoble (38100)",
          city_code: "38100",
          city_name: "grenoble",
          postal_code: "38000",
          region_code: "84",
          region_name: "Auvergne-Rhones-Alpes",
          street_name: "rue des Démarches",
          street_number: "2",
          street_address: "2 rue des Démarches",
          department_code: "38",
          department_name: "Isère",
          country_code: "FR",
          country_name: "France",
        }
      end
    end

    factory :champ_do_not_use_yes_no, class: 'ChampData' do
      type { 'Champs::YesNoChamp' }
      value { 'true' }
    end

    factory :champ_do_not_use_drop_down_list, class: 'ChampData' do
      type { 'Champs::DropDownListChamp' }
      transient do
        other { false }
      end
      value { 'val1' }
    end

    factory :champ_do_not_use_multiple_drop_down_list, class: 'ChampData' do
      type { 'Champs::MultipleDropDownListChamp' }
      value { '["val1", "val2"]' }
    end

    factory :champ_do_not_use_linked_drop_down_list, class: 'ChampData' do
      type { 'Champs::LinkedDropDownListChamp' }
      value { '["primary", "secondary"]' }
    end

    factory :champ_do_not_use_pays, class: 'ChampData' do
      type { 'Champs::PaysChamp' }
      value { 'France' }
    end

    factory :champ_do_not_use_regions, class: 'ChampData' do
      type { 'Champs::RegionChamp' }
      value { 'Guadeloupe' }
    end

    factory :champ_do_not_use_departements, class: 'ChampData' do
      type { 'Champs::DepartementChamp' }
      value { 'Ain' }
      external_id { '01' }
      value_json { { 'code_region' => '84', 'region_code' => '84', 'department_code' => '01' } }
    end

    factory :champ_do_not_use_communes, class: 'ChampData' do
      type { 'Champs::CommuneChamp' }
      external_id { '60172' }
      value { 'Coye-la-Forêt' }
      # what a real write via the champ writers produces (canonical + legacy keys)
      value_json do
        {
          'code_postal' => '60580',
          'postal_code' => '60580',
          'code_departement' => '60',
          'department_code' => '60',
          'code_region' => '32',
          'region_code' => '32',
          'city_name' => 'Coye-la-Forêt',
          'city_code' => '60172',
        }
      end
    end

    factory :champ_do_not_use_epci, class: 'ChampData' do
      type { 'Champs::EpciChamp' }
      value { 'CC Retz en Valois' }
      external_id { '200071991' }
    end

    factory :champ_do_not_use_dossier_link, class: 'ChampData' do
      type { 'Champs::DossierLinkChamp' }
      value { create(:dossier, :en_construction).id }
    end

    factory :champ_do_not_use_piece_justificative, class: 'ChampData' do
      type { 'Champs::PieceJustificativeChamp' }
      transient do
        size { 4 }
      end

      after(:build) do |champ, evaluator|
        champ.piece_justificative_file.attach(
          io: StringIO.new("x" * evaluator.size),
          filename: "toto.txt",
          content_type: "text/plain",
          # we don't want to run virus scanner on this file
          metadata: { virus_scan_result: ActiveStorage::VirusScanner::SAFE }
        )
      end
    end

    factory :champ_do_not_use_carte, class: 'ChampData' do
      type { 'Champs::CarteChamp' }
      geo_areas { build_list(:geo_area, 2) }
    end

    factory :champ_do_not_use_iban, class: 'ChampData' do
      type { 'Champs::IbanChamp' }
    end

    factory :champ_do_not_use_annuaire_education, class: 'ChampData' do
      type { 'Champs::AnnuaireEducationChamp' }
    end

    factory :champ_do_not_use_siret, class: 'ChampData' do
      type { 'Champs::SiretChamp' }
      association :etablissement, factory: [:etablissement]
      value { '44011762001530' }
      value_json { etablissement.champ_value_json }
    end

    factory :champ_do_not_use_rna, class: 'ChampData' do
      type { 'Champs::RNAChamp' }
      value { 'W173847273' }
      value_json { AddressProxy::ADDRESS_PARTS.index_by(&:itself).merge(title: "LA PRÉVENTION ROUTIERE", department_code: 'department_code') }
    end

    factory :champ_do_not_use_engagement_juridique, class: 'ChampData' do
      type { 'Champs::EngagementJuridiqueChamp' }
      value { 'EJ' }
    end

    factory :champ_do_not_use_pre_rempli, class: 'ChampData' do
      type { 'Champs::PreRempliChamp' }
    end

    factory :champ_do_not_use_cojo, class: 'ChampData' do
      type { 'Champs::COJOChamp' }
    end

    factory :champ_do_not_use_rnf, class: 'ChampData' do
      type { 'Champs::RNFChamp' }
      value { '075-FDD-00003-01' }
      external_id { '075-FDD-00003-01' }
      value_json { AddressProxy::ADDRESS_PARTS.index_by(&:itself).merge(title: "Fondation SFR", department_code: 'department_code') }
    end

    factory :champ_do_not_use_formatted, class: 'ChampData' do
      type { 'Champs::FormattedChamp' }
    end

    factory :champ_do_not_use_referentiel, class: 'ChampData' do
      type { 'Champs::ReferentielChamp' }
    end

    factory :champ_do_not_use_quotient_familial, class: 'ChampData' do
      type { 'Champs::QuotientFamilialChamp' }
    end
  end
end
