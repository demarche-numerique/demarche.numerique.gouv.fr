# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FAQsLoaderService do
  let(:substitutions) { { application_name: "demarche.numerique.gouv.fr", application_base_url: APPLICATION_BASE_URL, contact_email: CONTACT_EMAIL } }
  let(:service) { FAQsLoaderService.new(substitutions) }
  before(:each) { Rails.cache.clear }
  context "behavior with stubbed markdown files" do
    before do
      allow(Dir).to receive(:glob).and_return(['path/to/faq1.md', 'path/to/faq2.md'])

      # Mock File.read calls to fake md files
      # but call original otherwise (rspec or debuggning uses File.read to load some files)
      allow(File).to receive(:read).and_wrap_original do |original_method, *args|
        case args.first
        when 'path/to/faq1.md'
          <<~MD
            ---
            title: FAQ1
            slug: faq1
            category: usager
            subcategory: account
            ---
            Welcome to %{application_name}
          MD
        when 'path/to/faq2.md'
          <<~MD
            ---
            title: FAQ2
            slug: faq2
            category: admin
            subcategory: general
            ---
            This is for %{application_base_url}
          MD
        else
          original_method.call(*args)
        end
      end
    end

    describe '#find' do
      it 'returns a file with variable substitutions' do
        expect(service.find('usager/faq1').content).to include('Welcome to demarche.numerique.gouv.fr')
      end

      it 'caches file readings', caching: true do
        service # this load paths, and create a first hit on file
        expect(File).to have_received(:read).with('path/to/faq1.md').exactly(1).times

        2.times {
          service.find('usager/faq1')
          expect(File).to have_received(:read).with('path/to/faq1.md').exactly(2).times
        }

        # depends on substitutions and re-hit files
        service = FAQsLoaderService.new(substitutions.merge(application_name: "other name"))
        expect(File).to have_received(:read).with('path/to/faq1.md').exactly(3).times

        service.find('usager/faq1')
        expect(File).to have_received(:read).with('path/to/faq1.md').exactly(4).times
      end
    end

    describe '#all' do
      it 'returns all FAQs' do
        expect(service.all).to eq({
          "usager" => { "account" => [{ category: "usager", file_path: "path/to/faq1.md", slug: "faq1", subcategory: "account", title: "FAQ1" }] },
          "admin" => { "general" => [{ category: "admin", file_path: "path/to/faq2.md", slug: "faq2", subcategory: "general", title: "FAQ2" }] },
        })
      end

      it 'caches file readings', caching: true do
        2.times {
          service = FAQsLoaderService.new(substitutions)
          service.all
          expect(Dir).to have_received(:glob).once
        }

        # depends on substitutions
        service = FAQsLoaderService.new(substitutions.merge(application_name: "other name"))
        service.all
        expect(Dir).to have_received(:glob).twice
      end
    end

    describe '#faqs_for_category' do
      it 'returns FAQs grouped by subcategory for a given category' do
        result = service.faqs_for_category('usager')
        expect(result).to eq({
          'account' => [{ category: 'usager', subcategory: 'account', title: 'FAQ1', slug: 'faq1', file_path: 'path/to/faq1.md' }],
        })
      end
    end
  end

  context "with actual files" do
    it 'load, perform substitutions and returns all FAQs' do
      expect(service.all.keys).to match_array(["administrateur", "instructeur", "usager"])
    end
  end
end
