# frozen_string_literal: true

class ChangeRequiresIPFilteringDefault < ActiveRecord::Migration[8.0]
  def change
    change_column_default :api_tokens, :requires_ip_filtering, from: false, to: true
  end
end
