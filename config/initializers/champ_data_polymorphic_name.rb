# frozen_string_literal: true

# Polymorphic rows (active_storage_attachments) written before the
# Champ -> ChampData rename carry record_type 'Champ'; ChampData also keeps
# writing that historical name (see ChampData.polymorphic_name) so old and new
# rows stay uniform. Resolution must be patched on ActiveRecord::Base (not
# ApplicationRecord) because ActiveStorage::Attachment resolves record_type
# through its own base class, ActiveStorage::Record.
module ChampDataPolymorphicNameResolution
  def polymorphic_class_for(name)
    name == 'Champ' ? ChampData : super
  end
end

ActiveSupport.on_load(:active_record) do
  ActiveRecord::Base.singleton_class.prepend(ChampDataPolymorphicNameResolution)
end
