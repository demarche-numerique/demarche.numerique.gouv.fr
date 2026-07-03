# frozen_string_literal: true

module ChampHelpers
  # Builds a projected champ over an in-memory ChampData, for unit specs that
  # don't want a full dossier round-trip. Production code never builds
  # unpersisted champ data; specs are exempt.
  def build_projected_champ(type_de_champ, dossier: nil, row_id: nil, **data_attributes)
    dossier ||= build(:dossier)
    data = if data_attributes.present?
      ChampData.new(
        type: type_de_champ.champ_class.name,
        stable_id: type_de_champ.stable_id,
        stream: ChampData::MAIN_STREAM,
        private: type_de_champ.private?,
        dossier:,
        row_id:,
        **data_attributes
      )
    end
    type_de_champ.champ_class.new(dossier:, type_de_champ:, row_id:, data:)
  end

  # Write raw champ data attributes and realign the champ's copied in-memory
  # attributes, bypassing champ writers (simulates pre-existing row state).
  def write_champ_data_attributes(champ, **attributes)
    attributes.each { |name, value| champ.champ_data.write_attribute(name, value) }
    champ.send(:copy_attributes_from_data)
    champ
  end
end

RSpec.configure do |config|
  config.include ChampHelpers
end
