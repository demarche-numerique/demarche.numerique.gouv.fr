# frozen_string_literal: true

require "rails_helper"

RSpec.describe Dsfr::ToggleComponent, type: :component do
  def render_with_form(component_options: {}, **form_options)
    cmp = nil
    ActionView::Base.empty.form_with(**form_options) do |form|
      cmp = described_class.new(form:, target: :include_archived, html_title: "Include archived", **component_options)
    end
    render_inline(cmp).to_html
  end

  def extract_input_id(html)
    html[/<input class="fr-toggle__input"[^>]*id="([^"]+)"/, 1]
  end

  def extract_label_for(html)
    html[/<label[^>]*for="([^"]+)"/, 1]
  end

  context "with a form_with and a namespace but no object" do
    let(:html) { render_with_form(url: "/fake", namespace: "export1") }

    it "produces identical values for the input id and the label for attributes" do
      expect(extract_input_id(html)).to eq("export1_include_archived")
      expect(extract_label_for(html)).to eq("export1_include_archived")
    end

    it "does not double-prefix the namespace" do
      expect(html).not_to include("export1_export1_include_archived")
    end
  end

  context "with a form_with without namespace nor object" do
    let(:html) { render_with_form(url: "/fake") }

    it "produces identical values for the input id and the label for attributes" do
      expect(extract_input_id(html)).to be_present
      expect(extract_input_id(html)).to eq(extract_label_for(html))
    end
  end

  context "with a form_with bound to a model" do
    let(:procedure) { build_stubbed(:procedure) }
    let(:html) { render_with_form(model: procedure, url: "/fake") }

    it "produces identical values for the input id and the label for attributes" do
      expect(extract_input_id(html)).to be_present
      expect(extract_input_id(html)).to eq(extract_label_for(html))
    end
  end

  context "with opt: data attributes (used as Stimulus targets)" do
    let(:html) do
      render_with_form(
        url: "/fake",
        component_options: { opt: { "hide-target_target": "source" } }
      )
    end

    it "renders the data attributes on the input element" do
      expect(html).to match(/<input class="fr-toggle__input"[^>]*data-hide-target-target="source"/)
    end
  end

  context "with two forms using different namespaces on the same page" do
    it "generates distinct ids so multiple toggles can coexist without breaking DSFR init" do
      first = render_with_form(url: "/fake", namespace: "export1")
      second = render_with_form(url: "/fake", namespace: "export_template_1")

      expect(extract_input_id(first)).to eq("export1_include_archived")
      expect(extract_label_for(first)).to eq("export1_include_archived")
      expect(extract_input_id(second)).to eq("export_template_1_include_archived")
      expect(extract_label_for(second)).to eq("export_template_1_include_archived")
    end
  end
end
