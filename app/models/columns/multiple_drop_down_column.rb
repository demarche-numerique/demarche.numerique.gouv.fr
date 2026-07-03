# frozen_string_literal: true

class Columns::MultipleDropDownColumn < Columns::JSONPathColumn
  private

  def typed_value(champ_data)
    JsonPath.on(champ_data.value_json, jsonpath).join(', ')
  end
end
