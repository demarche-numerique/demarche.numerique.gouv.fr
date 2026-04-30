# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.xdescribe T20260408BackfillReferentielTiptapColumnsTask do
    subject(:task) { described_class.new }

    let(:url_tiptap) do
      {
        "type" => "doc",
        "content" => [
          {
            "type" => "paragraph",
            "content" => [
              { "type" => "text", "text" => "https://rnb-api.beta.gouv.fr/api/alpha/buildings/" },
              { "type" => "mention", "attrs" => { "id" => "{query}", "label" => "Valeur saisie par l'usager" } },
            ],
          },
        ],
      }
    end

    describe "#collection" do
      let!(:not_migrated) { create(:api_referentiel, :exact_match) }
      let!(:already_migrated) { create(:api_referentiel, :exact_match).tap { _1.update_column(:use_tiptap, true) } }

      it "returns only referentiels with use_tiptap false" do
        expect(task.collection).to include(not_migrated)
        expect(task.collection).not_to include(already_migrated)
      end
    end

    describe "#process" do
      let(:api_client) { instance_double(API::Client) }

      before do
        allow(API::Client).to receive(:new).and_return(api_client)
      end

      context "with URL containing {id}" do
        let(:referentiel) { create(:api_referentiel, :exact_match, url: "https://rnb-api.beta.gouv.fr/api/alpha/buildings/{id}/", last_response: nil) }

        it "converts url to tiptap JSON with {query} mention" do
          task.process(referentiel)
          referentiel.reload

          expected = {
            "type" => "doc",
            "content" => [
              {
                "type" => "paragraph",
                "content" => [
                  { "type" => "text", "text" => "https://rnb-api.beta.gouv.fr/api/alpha/buildings/" },
                  { "type" => "mention", "attrs" => { "id" => "{query}", "label" => "Valeur saisie par l'usager" } },
                  { "type" => "text", "text" => "/" },
                ],
              },
            ],
          }
          expect(referentiel.url_tiptap).to eq(expected)
        end

        it "converts test_data to tiptap hash" do
          task.process(referentiel)
          referentiel.reload

          expect(referentiel.test_data_tiptap).to eq({ "{query}" => "PG46YY6YWCX8" })
        end
      end

      context "with URL without {id}" do
        let(:referentiel) { create(:api_referentiel, mode: 'exact_match', url: "https://api.gouv.fr/data", test_data: "test", last_response: nil) }

        it "converts to tiptap JSON with text only" do
          task.process(referentiel)
          referentiel.reload

          expected = {
            "type" => "doc",
            "content" => [
              {
                "type" => "paragraph",
                "content" => [
                  { "type" => "text", "text" => "https://api.gouv.fr/data" },
                ],
              },
            ],
          }
          expect(referentiel.url_tiptap).to eq(expected)
        end
      end

      context "with blank test_data" do
        let(:referentiel) { create(:api_referentiel, mode: 'exact_match', url: "https://api.gouv.fr/{id}", test_data: "placeholder", last_response: nil) }

        before { referentiel.update_column(:test_data, nil) }

        it "sets test_data_tiptap to nil" do
          task.process(referentiel)
          referentiel.reload

          expect(referentiel.test_data_tiptap).to be_nil
        end
      end

      context "with URL having multiple {id} occurrences" do
        let(:referentiel) { create(:api_referentiel, mode: 'exact_match', url: "https://api.gouv.fr/{id}/details/{id}", test_data: "abc", last_response: nil) }

        it "converts each {id} to a {query} mention" do
          task.process(referentiel)
          referentiel.reload

          mentions = referentiel.url_tiptap.dig("content", 0, "content")
            .filter { _1["type"] == "mention" }

          expect(mentions.size).to eq(2)
          expect(mentions).to all(include("attrs" => { "id" => "{query}", "label" => "Valeur saisie par l'usager" }))
        end
      end

      describe "activation" do
        context "when referentiel has no URL (not configured)" do
          let(:referentiel) { create(:api_referentiel, mode: 'exact_match', url: "https://api.gouv.fr/{id}", test_data: "x") }

          before { referentiel.update_columns(url: nil, test_data: nil) }

          it "activates use_tiptap directly" do
            task.process(referentiel)
            expect(referentiel.reload.use_tiptap).to be true
          end
        end

        context "when referentiel has no last_response" do
          let(:referentiel) { create(:api_referentiel, :exact_match, last_response: nil) }

          it "activates use_tiptap directly" do
            task.process(referentiel)
            expect(referentiel.reload.use_tiptap).to be true
          end
        end

        context "when API response matches baseline status" do
          let(:referentiel) { create(:api_referentiel, :exact_match, last_response: { status: 200, body: {} }) }

          before do
            allow(api_client).to receive(:call).and_return(Dry::Monads::Result::Success.new({ body: {} }))
          end

          it "activates use_tiptap" do
            task.process(referentiel)
            expect(referentiel.reload.use_tiptap).to be true
          end
        end

        context "when API response status differs from baseline" do
          let(:referentiel) { create(:api_referentiel, :exact_match, last_response: { status: 200, body: {} }) }

          before do
            allow(api_client).to receive(:call).and_return(Dry::Monads::Result::Failure.new({ code: 500, body: "error" }))
          end

          it "does not activate use_tiptap" do
            task.process(referentiel)
            expect(referentiel.reload.use_tiptap).to be false
          end

          it "reports to Sentry" do
            allow(Sentry).to receive(:capture_message)
            task.process(referentiel)
            expect(Sentry).to have_received(:capture_message).with("BackfillReferentielTiptap: status mismatch", extra: hash_including(referentiel_id: referentiel.id))
          end
        end

        context "when tiptap URL cannot be resolved" do
          let(:referentiel) { create(:api_referentiel, mode: 'exact_match', url: "https://api.gouv.fr/{id}", test_data: "x", last_response: { status: 200, body: {} }) }

          before { referentiel.update_column(:test_data, nil) }

          it "does not activate use_tiptap" do
            task.process(referentiel)
            expect(referentiel.reload.use_tiptap).to be false
          end

          it "reports to Sentry" do
            allow(Sentry).to receive(:capture_message)
            task.process(referentiel)
            expect(Sentry).to have_received(:capture_message).with("BackfillReferentielTiptap: could not resolve tiptap URL", extra: hash_including(referentiel_id: referentiel.id))
          end
        end
      end
    end
  end
end
