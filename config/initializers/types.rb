# frozen_string_literal: true

require Rails.root.join("app/types/column_type")
require Rails.root.join("app/types/personnalisation_column_type")
require Rails.root.join("app/types/export_item_type")
require Rails.root.join("app/types/sorted_column_type")
require Rails.root.join("app/types/filtered_column_type")
require Rails.root.join("app/types/exported_column_type")
require Rails.root.join("app/types/external_data_exception_type")
require Rails.root.join("app/types/type_de_champ_tree_type")

ActiveSupport.on_load(:active_record) do
  ActiveRecord::Type.register(:column, ColumnType)
  ActiveRecord::Type.register(:personnalisation_column, PersonnalisationColumnType)
  ActiveRecord::Type.register(:export_item, ExportItemType)
  ActiveRecord::Type.register(:sorted_column, SortedColumnType)
  ActiveRecord::Type.register(:filtered_column, FilteredColumnType)
  ActiveRecord::Type.register(:exported_column, ExportedColumnType)
  ActiveRecord::Type.register(:external_data_exception, ExternalDataExceptionType)
  ActiveRecord::Type.register(:type_de_champ_tree, TypeDeChampTreeType)
end
