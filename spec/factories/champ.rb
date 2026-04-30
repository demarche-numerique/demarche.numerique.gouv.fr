# frozen_string_literal: true

FactoryBot.define do
  factory :champ_do_not_use, class: 'Champ' do
    stream { 'main' }
    add_attribute(:private) { false }

    factory :champ_do_not_use_text, class: 'Champs::TextChamp' do
      value { 'text' }
    end

    factory :champ_do_not_use_textarea, class: 'Champs::TextareaChamp' do
      value { 'textarea' }
    end

    factory :champ_do_not_use_date, class: 'Champs::DateChamp' do
      value { '2019-07-10' }
    end

    factory :champ_do_not_use_datetime, class: 'Champs::DatetimeChamp' do
      value { '15/09/1962 15:35' }
    end

    factory :champ_do_not_use_number, class: 'Champs::NumberChamp' do
      value { '42' }
    end

    factory :champ_do_not_use_decimal_number, class: 'Champs::DecimalNumberChamp' do
      value { '42.1' }
    end

    factory :champ_do_not_use_integer_number, class: 'Champs::IntegerNumberChamp' do
      value { '42' }
    end

    factory :champ_do_not_use_checkbox, class: 'Champs::CheckboxChamp' do
      value { 'true' }
    end

    factory :champ_do_not_use_civilite, class: 'Champs::CiviliteChamp' do
      value { 'M.' }
    end

    factory :champ_do_not_use_email, class: 'Champs::EmailChamp' do
      value { 'yoda@beta.gouv.fr' }
    end

    factory :champ_do_not_use_phone, class: 'Champs::PhoneChamp' do
      value { '0666666666' }
    end

    factory :champ_do_not_use_address, class: 'Champs::AddressChamp' do
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

    factory :champ_do_not_use_yes_no, class: 'Champs::YesNoChamp' do
      value { 'true' }
    end

    factory :champ_do_not_use_drop_down_list, class: 'Champs::DropDownListChamp' do
      transient do
        other { false }
      end
      value { 'val1' }
    end

    factory :champ_do_not_use_multiple_drop_down_list, class: 'Champs::MultipleDropDownListChamp' do
      value { '["val1", "val2"]' }
    end

    factory :champ_do_not_use_linked_drop_down_list, class: 'Champs::LinkedDropDownListChamp' do
      value { '["primary", "secondary"]' }
    end

    factory :champ_do_not_use_pays, class: 'Champs::PaysChamp' do
      value { 'France' }
    end

    factory :champ_do_not_use_regions, class: 'Champs::RegionChamp' do
      value { 'Guadeloupe' }
    end

    factory :champ_do_not_use_departements, class: 'Champs::DepartementChamp' do
      value { '01' }
    end

    factory :champ_do_not_use_communes, class: 'Champs::CommuneChamp' do
      external_id { '60172' }
      code_postal { '60580' }
    end

    factory :champ_do_not_use_epci, class: 'Champs::EpciChamp' do
      value { 'CC Retz en Valois' }
      external_id { '200071991' }
    end

    factory :champ_do_not_use_dossier_link, class: 'Champs::DossierLinkChamp' do
      value { create(:dossier, :en_construction).id }
    end

    factory :champ_do_not_use_piece_justificative, class: 'Champs::PieceJustificativeChamp' do
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

    factory :champ_do_not_use_carte, class: 'Champs::CarteChamp' do
      geo_areas { build_list(:geo_area, 2) }
    end

    factory :champ_do_not_use_iban, class: 'Champs::IbanChamp' do
    end

    factory :champ_do_not_use_annuaire_education, class: 'Champs::AnnuaireEducationChamp' do
    end

    factory :champ_do_not_use_cnaf, class: 'Champs::CnafChamp' do
    end

    factory :champ_do_not_use_dgfip, class: 'Champs::DgfipChamp' do
    end

    factory :champ_do_not_use_pole_emploi, class: 'Champs::PoleEmploiChamp' do
    end

    factory :champ_do_not_use_mesri, class: 'Champs::MesriChamp' do
    end

    factory :champ_do_not_use_siret, class: 'Champs::SiretChamp' do
      association :etablissement, factory: [:etablissement]
      value { '44011762001530' }
      value_json { etablissement.champ_value_json }
    end

    factory :champ_do_not_use_rna, class: 'Champs::RNAChamp' do
      value { 'W173847273' }
      value_json { AddressProxy::ADDRESS_PARTS.index_by(&:itself).merge(title: "LA PRÉVENTION ROUTIERE", department_code: 'department_code') }
    end

    factory :champ_do_not_use_engagement_juridique, class: 'Champs::EngagementJuridiqueChamp' do
      value { 'EJ' }
    end

    factory :champ_do_not_use_cojo, class: 'Champs::COJOChamp' do
    end

    factory :champ_do_not_use_rnf, class: 'Champs::RNFChamp' do
      value { '075-FDD-00003-01' }
      external_id { '075-FDD-00003-01' }
      value_json { AddressProxy::ADDRESS_PARTS.index_by(&:itself).merge(title: "Fondation SFR", department_code: 'department_code') }
    end

    factory :champ_do_not_use_formatted, class: 'Champs::FormattedChamp' do
    end

    factory :champ_do_not_use_referentiel, class: 'Champs::ReferentielChamp' do
    end

    factory :champ_do_not_use_quotient_familial, class: 'Champs::QuotientFamilialChamp' do
    end
  end
end
