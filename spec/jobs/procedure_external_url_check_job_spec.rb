# frozen_string_literal: true

describe ProcedureExternalURLCheckJob do
  subject(:perform) { described_class.new(procedure).perform_now; procedure.reload }
  let(:lien_dpo) { "https://example.com/dpo" }
  let(:lien_notice) { "https://example.com/notice" }
  let(:lien_dpo_error) { nil }
  let(:dpo_code) { 200 }
  let(:notice_code) { 200 }
  let(:procedure) { create(:procedure, lien_dpo:, lien_dpo_error:, lien_notice:) }

  before do
    allow(Typhoeus).to receive(:get).with("https://example.com/dpo", followlocation: true).and_return(Typhoeus::Response.new(code: dpo_code, redirect_count: 0, mock: true))
    allow(Typhoeus).to receive(:get).with("https://example.com/notice", followlocation: true).and_return(Typhoeus::Response.new(code: notice_code, redirect_count: 0, mock: true))
  end

  context 'with valid links' do
    it "changes nothing" do
      perform

      expect(procedure.lien_dpo).to be_present
      expect(procedure.lien_notice).to be_present
      expect(procedure.lien_dpo_error).to be_nil
      expect(procedure.lien_notice_error).to be_nil
    end
  end

  context 'with invalid dpo' do
    let(:dpo_code) { 404 }

    it "update dpo error" do
      perform
      expect(procedure.lien_dpo_error).to include("404")
    end
  end

  context "with invalid lien_dpo attribute" do
    before do
      procedure.lien_dpo = "http://localhost"
      procedure.save!(validate: false)
    end

    it "update dpo error" do
      perform

      expect(procedure.lien_dpo_error).to include("pas un lien valide")
    end
  end

  context 'when there was an error before' do
    let(:lien_dpo_error) { "old error" }

    it "removes error when link is valid" do
      perform

      expect(procedure.lien_dpo_error).to be_nil
    end
  end

  context 'with invalid notice link' do
    let(:notice_code) { 500 }

    it "updates lien_notice_error" do
      perform

      expect(procedure.lien_notice_error).to include("500")
    end
  end

  context 'when there are other errors' do
    let(:notice_code) { 404 }
    before do
      procedure.libelle = nil
      procedure.save!(validate: false)
    end

    it "does not fail the job" do
      perform

      expect(procedure.lien_notice_error).to include("404")
    end
  end
end
