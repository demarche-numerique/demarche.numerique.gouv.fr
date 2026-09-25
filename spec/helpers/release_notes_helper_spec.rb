# frozen_string_literal: true

RSpec.describe ReleaseNotesHelper, type: :helper do
  describe "#render_release_note_content" do
    let(:release_note) { build(:release_note) }

    it "adds the external link attributes to absolute links" do
      release_note.body = "Go to <a href='http://example.com'>Example</a>"
      processed_content = helper.render_release_note_content(release_note.body)

      expect(processed_content.body.to_s).to include('Go to <a href="http://example.com" target="_blank" rel="noopener external" title="example.com — Nouvel onglet">Example</a>')
    end

    it "handles content without links" do
      release_note.body = "No links here"
      processed_content = helper.render_release_note_content(release_note.body)

      expect(processed_content.body.to_s).to include("No links here")
    end

    context "image" do
      let(:release_note) { build(:release_note, body: '<img src="http://example.com/image.png">') }

      it "renders img tag" do
        processed_content = helper.render_release_note_content(release_note.body)

        expect(processed_content.body.to_s).to include('<img src="http://example.com/image.png">')
      end
    end
  end
end
