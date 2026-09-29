# frozen_string_literal: true

RSpec.describe ReleaseNotesHelper, type: :helper do
  describe "#render_release_note_content" do
    let(:release_note) { build(:release_note) }

    it "adds the external link attributes to absolute links" do
      release_note.body = "Go to <a href='http://example.com'>Example</a>"
      processed_content = helper.render_release_note_content(release_note.body)

      expect(processed_content.body.to_s).to include('Go to <a href="http://example.com" title="Example — Nouvel onglet" target="_blank" rel="noopener external">Example</a>')
    end

    it "strips whitespace around the href" do
      release_note.body = "Go to <a href=' http://example.com/doc '>Example</a>"
      processed_content = helper.render_release_note_content(release_note.body)

      expect(processed_content.body.to_s).to include('<a href="http://example.com/doc" title="Example — Nouvel onglet" target="_blank" rel="noopener external">Example</a>')
    end

    it "strips non-breaking spaces around the href" do
      release_note.body = "Go to <a href='http://example.com/doc\u00A0'>Example</a>"
      processed_content = helper.render_release_note_content(release_note.body)

      expect(processed_content.body.to_s).to include('<a href="http://example.com/doc" ')
    end

    ["mailto:contact", "gid:foo", "http://exa mple.com"].each do |href|
      it "keeps rendering when the href is #{href}" do
        release_note.body = "Go to <a href='#{href}'>Example</a>"
        processed_content = helper.render_release_note_content(release_note.body)

        expect(processed_content.body.to_s).to include('title="Example — Nouvel onglet" target="_blank" rel="noopener external">Example</a>')
      end
    end

    it "falls back to a bare new tab title when the link has no text" do
      release_note.body = "Go to <a href='http://example.com'> </a>"
      processed_content = helper.render_release_note_content(release_note.body)

      expect(processed_content.body.to_s).to include('title="Nouvel onglet"')
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
