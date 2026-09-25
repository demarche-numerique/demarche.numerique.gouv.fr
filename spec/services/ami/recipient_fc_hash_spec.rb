# frozen_string_literal: true

require 'rails_helper'
require 'csv'

RSpec.describe Ami::RecipientFcHash do
  describe '.call' do
    let(:user) { create(:user) }

    # La fixture est la copie conforme du jeu de test fourni par AMI.
    it 'matches expected hashes from the CSV fixture' do
      rows = CSV.read(
        Rails.root.join('spec/fixtures/files/ami/fc_recipient_hashes.csv'),
        headers: true
      )

      rows.each do |row|
        fc_information = instance_double(
          FranceConnectInformation.name,
          given_name: row.fetch('prenoms'),
          family_name: row.fetch('nomDeNaissance'),
          birthdate: row.fetch('dateDeNaissance'),
          gender: row.fetch('genre'),
          birthplace: row.fetch('codePostalLieuDeNaissance'),
          birthcountry: row.fetch('codePaysDeNaissance')
        )
        fc_association = double('FranceConnectInformationAssociation', order: [fc_information])
        allow(user).to receive(:france_connect_informations).and_return(fc_association)

        computed_hash = described_class.call(user)
        expect(computed_hash).to eq(row.fetch('hash')),
          "row id=#{row.fetch('id')} does not match #{computed_hash} != #{row.fetch('hash')}"
      end
    end
  end
end
