# frozen_string_literal: true

describe Champs::PhoneChamp do
  let(:types_de_champ_public) { [{ type: :phone }] }
  let(:procedure) { create(:procedure, types_de_champ_public:) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:champ) { dossier.root_public_champs.first }

  describe '#validate' do
    it do
      expect(champ_with_value(nil).validate(:champ_value)).to be_truthy
      expect(champ_with_value("0123456789 0123456789").validate(:champ_value)).to_not be_truthy
      expect(champ_with_value("01.23.45.67.89 01.23.45.67.89").validate(:champ_value)).to_not be_truthy
      expect(champ_with_value("3646").validate(:champ_value)).to be_truthy
      expect(champ_with_value("0123456789").validate(:champ_value)).to be_truthy
      expect(champ_with_value("01.23.45.67.89").validate(:champ_value)).to be_truthy
      expect(champ_with_value("0123 45.67.89").validate(:champ_value)).to be_truthy
      expect(champ_with_value("0033 123-456-789").validate(:champ_value)).to be_truthy
      expect(champ_with_value("0033 123-456-789").validate(:champ_value)).to be_truthy
      expect(champ_with_value("0033(0)123456789").validate(:champ_value)).to be_truthy
      expect(champ_with_value("+33-1.23.45.67.89").validate(:champ_value)).to be_truthy
      expect(champ_with_value("+33 - 123 456 789").validate(:champ_value)).to be_truthy
      expect(champ_with_value("+33(0) 123 456 789").validate(:champ_value)).to be_truthy
      expect(champ_with_value("+33 (0)123 45 67 89").validate(:champ_value)).to be_truthy
      expect(champ_with_value("+33 (0)1 2345-6789").validate(:champ_value)).to be_truthy
      expect(champ_with_value("+33(0) - 123456789").validate(:champ_value)).to be_truthy
      expect(champ_with_value("+1(0) - 123456789").validate(:champ_value)).to be_truthy
      expect(champ_with_value("+49 2109 87654321").validate(:champ_value)).to be_truthy
      expect(champ_with_value("012345678").validate(:champ_value)).to be_truthy
      # DROM numbers should be valid
      expect(champ_with_value("06 96 04 78 07").validate(:champ_value)).to be_truthy
      expect(champ_with_value("05 94 22 31 31").validate(:champ_value)).to be_truthy
      expect(champ_with_value("+594 5 94 22 31 31").validate(:champ_value)).to be_truthy
      # polynesian numbers should not return errors in any way
      ## landline numbers start with 40 or 45
      expect(champ_with_value("45187272").validate(:champ_value)).to be_truthy
      expect(champ_with_value("40 473 500").validate(:champ_value)).to be_truthy
      expect(champ_with_value("40473500").validate(:champ_value)).to be_truthy
      expect(champ_with_value("45473500").validate(:champ_value)).to be_truthy
      ## +689 is the international indicator
      expect(champ_with_value("+689 45473500").validate(:champ_value)).to be_truthy
      expect(champ_with_value("0145473500").validate(:champ_value)).to be_truthy
      ## polynesian mobile numbers start with 87, 88, 89
      expect(champ_with_value("87473500").validate(:champ_value)).to be_truthy
      expect(champ_with_value("88473500").validate(:champ_value)).to be_truthy
      expect(champ_with_value("89473500").validate(:champ_value)).to be_truthy
    end
  end

  describe '#to_s' do
    context 'for valid phone numbers' do
      it 'returns the national part of the number, formatted nicely' do
        expect(champ_with_value("0115789055").to_s).to eq("01 15 78 90 55")
        expect(champ_with_value("+33115789055").to_s).to eq("01 15 78 90 55")
        # DROM phone numbers are formatted differently – but still formatted
        expect(champ_with_value("0696047807").to_s).to eq("0696 04 78 07")
        expect(champ_with_value("45187272").to_s).to eq("45187272")
      end
    end

    context 'for possible (but not valid) phone numbers' do
      it 'returns the original' do
        expect(champ_with_value("1234").to_s).to eq("1234")
      end
    end
  end

  def champ_with_value(number)
    champ.tap { |c| c.value = number }
  end
end
