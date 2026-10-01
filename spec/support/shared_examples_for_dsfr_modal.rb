# frozen_string_literal: true

# The dialog's accessible name must come from exactly one element of the page:
# a duplicated or dangling aria-labelledby leaves the modal unnamed (RGAA 7.1).
# Deriving the title id from the dialog id keeps it unique across modals.
# The including group defines `modal_html`, the HTML to search.
RSpec.shared_examples 'a labelled DSFR modal' do |dialog_id|
  it "labels ##{dialog_id} with its own title" do
    html = Capybara.string(modal_html)
    dialog = html.find("dialog##{dialog_id}", visible: :all)
    title_id = dialog['aria-labelledby']

    expect(title_id).to eq("#{dialog_id}-title")
    expect(html).to have_css("##{title_id}", visible: :all, count: 1)
    expect(dialog).to have_css("##{title_id}.fr-modal__title", visible: :all)
  end
end
