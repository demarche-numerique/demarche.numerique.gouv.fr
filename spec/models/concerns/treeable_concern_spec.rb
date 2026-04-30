# frozen_string_literal: true

describe TreeableConcern do
  class ChampsToTree
    include TreeableConcern

    attr_reader :root
    def initialize(types_de_champ:)
      @root = to_tree(types_de_champ:)
    end
  end

  subject { ChampsToTree.new(types_de_champ:).root }
  describe "to_tree" do
    let(:procedure) { create(:procedure, types_de_champ_public:) }
    let(:types_de_champ_public) { [] }
    let(:types_de_champ) { procedure.active_revision.types_de_champ_public }

    let(:header_1) { { type: :header_section, level: 1, stable_id: 99 } }
    let(:header_1_2) { { type: :header_section, level: 2, stable_id: 199 } }
    let(:header_2) { { type: :header_section, level: 1, stable_id: 299 } }
    let(:champ_text) { { stable_id: 399 } }
    let(:champ_textarea) { { type: :textarea, stable_id: 499 } }
    let(:champ_explication) { { type: :explication, stable_id: 599 } }
    let(:champ_communes) { { type: :communes, stable_id: 699 } }

    let(:header_1_tdc) { procedure.active_revision.types_de_champ_public.find { _1.stable_id == 99 } }
    let(:header_1_2_tdc) { procedure.active_revision.types_de_champ_public.find { _1.stable_id == 199 } }
    let(:header_2_tdc) { procedure.active_revision.types_de_champ_public.find { _1.stable_id == 299 } }
    let(:champ_text_tdc) { procedure.active_revision.types_de_champ_public.find { _1.stable_id == 399 } }
    let(:champ_textarea_tdc) { procedure.active_revision.types_de_champ_public.find { _1.stable_id == 499 } }
    let(:champ_explication_tdc) { procedure.active_revision.types_de_champ_public.find { _1.stable_id == 599 } }
    let(:champ_communes_tdc) { procedure.active_revision.types_de_champ_public.find { _1.stable_id == 699 } }

    context 'without section' do
      let(:types_de_champ_public) do
        [
          champ_text, champ_textarea,
        ]
      end
      it 'inlines champs at root level' do
        expect(subject.size).to eq(types_de_champ.size)
        expect(subject).to eq([champ_text_tdc, champ_textarea_tdc])
      end
    end

    context 'with header_section and champs' do
      let(:types_de_champ_public) do
        [
          header_1,
          champ_explication,
          champ_text,
          header_2,
          champ_textarea,
        ]
      end

      it 'wraps champs within preview header section' do
        expect(subject.size).to eq(2)
        expect(subject).to eq([
          [header_1_tdc, champ_explication_tdc, champ_text_tdc],
          [header_2_tdc, champ_textarea_tdc],
        ])
      end
    end

    context 'leading champs, and in between sections only' do
      let(:champ_textarea_bis) { { type: :textarea, stable_id: 799 } }
      let(:champ_textarea_bis_tdc) { procedure.active_revision.types_de_champ_public.find { _1.stable_id == 799 } }
      let(:types_de_champ_public) do
        [
          champ_text,
          champ_textarea,
          header_1,
          champ_explication,
          champ_communes,
          header_2,
          champ_textarea_bis,
        ]
      end
      it 'chunk by uniq champs' do
        expect(subject.size).to eq(4)
        expect(subject).to eq([
          champ_text_tdc,
          champ_textarea_tdc,
          [header_1_tdc, champ_explication_tdc, champ_communes_tdc],
          [header_2_tdc, champ_textarea_bis_tdc],
        ])
      end
    end

    context 'with one sub sections' do
      let(:types_de_champ_public) do
        [
          header_1,
          champ_explication,
          header_1_2,
          champ_communes,
          header_2,
          champ_textarea,
        ]
      end
      it 'chunk by uniq champs' do
        expect(subject.size).to eq(2)
        expect(subject).to eq([
          [header_1_tdc, champ_explication_tdc, [header_1_2_tdc, champ_communes_tdc]],
          [header_2_tdc, champ_textarea_tdc],
        ])
      end
    end

    context 'with consecutive subsection' do
      let(:header_1_2_1) { { type: :header_section, level: 2, stable_id: 799 } }
      let(:header_1_2_2) { { type: :header_section, level: 2, stable_id: 899 } }
      let(:header_1_2_3) { { type: :header_section, level: 2, stable_id: 999 } }

      let(:header_1_2_1_tdc) { procedure.active_revision.types_de_champ_public.find { _1.stable_id == 799 } }
      let(:header_1_2_2_tdc) { procedure.active_revision.types_de_champ_public.find { _1.stable_id == 899 } }
      let(:header_1_2_3_tdc) { procedure.active_revision.types_de_champ_public.find { _1.stable_id == 999 } }

      let(:types_de_champ_public) do
       [
         header_1,
         header_1_2_1,
         champ_text,
         header_1_2_2,
         champ_textarea,
         header_1_2_3,
         champ_communes,
       ]
     end
      it 'chunk by uniq champs' do
        expect(subject.size).to eq(1)
        expect(subject).to eq([
          [
            header_1_tdc,
            [header_1_2_1_tdc, champ_text_tdc],
            [header_1_2_2_tdc, champ_textarea_tdc],
            [header_1_2_3_tdc, champ_communes_tdc],
          ],
        ])
      end
    end

    context 'with skipped header level (h1 then h3, no h2)' do
      let(:header_1_3) { { type: :header_section, level: 3, stable_id: 799 } }
      let(:header_1_3_tdc) { procedure.active_revision.types_de_champ_public.find { _1.stable_id == 799 } }

      let(:types_de_champ_public) do
        [
          header_1,
          champ_text,
          header_1_3,
          champ_textarea,
        ]
      end

      it 'attaches to nearest existing ancestor instead of crashing' do
        expect(subject.size).to eq(1)
        expect(subject).to eq([
          [header_1_tdc, champ_text_tdc, [header_1_3_tdc, champ_textarea_tdc]],
        ])
      end
    end

    context 'with one sub sections and one subsub section' do
      let(:header_1_2_3) { { type: :header_section, level: 3, stable_id: 799 } }
      let(:header_1_2_3_tdc) { procedure.active_revision.types_de_champ_public.find { _1.stable_id == 799 } }

      let(:types_de_champ_public) do
        [
          header_1,
          champ_explication,
          header_1_2,
          champ_communes,
          header_1_2_3,
          champ_text,
          header_2,
          champ_textarea,
        ]
      end

      it 'chunk by uniq champs' do
        expect(subject.size).to eq(2)
        expect(subject).to eq([
          [
            header_1_tdc,
            champ_explication_tdc,
            [
              header_1_2_tdc,
              champ_communes_tdc,
              [
                header_1_2_3_tdc, champ_text_tdc,
              ],
            ],
          ],
          [
            header_2_tdc,
            champ_textarea_tdc,
          ],
        ])
      end
    end
  end
end
