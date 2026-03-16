# frozen_string_literal: true

class AutosaveNoticeComponentPreview < ViewComponent::Preview
  def success
    render AutosaveNoticeComponent.new(success: true, label_scope: :form)
  end

  def error
    render AutosaveNoticeComponent.new(success: false, label_scope: :form)
  end
end
