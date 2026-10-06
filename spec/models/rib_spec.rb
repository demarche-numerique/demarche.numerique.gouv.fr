# frozen_string_literal: true

describe RIB do
  describe '#account_holder_matches?' do
    def matches?(account_holder, **applicant) = RIB.new(account_holder:).account_holder_matches?(**applicant)

    context 'with a personne physique' do
      it 'needs the first name and the last name, in any order' do
        expect(matches?("M JEAN DUPONT\n12 RUE DE LA PAIX\n75002 PARIS", first_name: 'Jean', last_name: 'Dupont')).to eq(true)
        expect(matches?('MME LEFEVRE JEAN PIERRE', first_name: 'Jean-Pierre', last_name: 'Lefèvre')).to eq(true)
        expect(matches?('M JEAN DUPONT', first_name: 'Marie', last_name: 'Dupont')).to eq(false)
        expect(matches?('M JEAN MARTIN', first_name: 'Jean', last_name: 'Dupont')).to eq(false)
        expect(matches?('M JEAN MARTINEZ', first_name: 'Jean', last_name: 'Martin')).to eq(false)
      end

      it 'only needs the first first name' do
        expect(matches?('M XAVIER JULIEN', first_name: 'Xavier Jean-Marie', last_name: 'Julien')).to eq(true)
        expect(matches?('M JEAN MARIE JULIEN', first_name: 'Xavier Jean-Marie', last_name: 'Julien')).to eq(false)
      end

      it 'only needs the last name on a joint account' do
        expect(matches?("M OU MME DUPONT\n1 RUE X", first_name: 'Jean', last_name: 'Dupont')).to eq(true)
        expect(matches?('MONSIEUR ET MADAME DUPONT', first_name: 'Jean', last_name: 'Dupont')).to eq(true)
        expect(matches?('M DUPONT', first_name: 'Jean', last_name: 'Dupont')).to eq(false)
        expect(matches?('M OU MME MARTIN', first_name: 'Jean', last_name: 'Dupont')).to eq(false)
        expect(matches?('M OU MME MARTINEZ', first_name: 'Jean', last_name: 'Martin')).to eq(false)
      end

      it 'only needs the last name without a first name' do
        expect(matches?('M DUPONT', first_name: nil, last_name: 'Dupont')).to eq(true)
        expect(matches?('M MARTIN', first_name: nil, last_name: 'Dupont')).to eq(false)
      end

      it 'only leaves out civilities, particles being part of the name' do
        expect(matches?('M JEAN LE GOFF', first_name: 'Jean', last_name: 'Le Goff')).to eq(true)
        expect(matches?('M JEAN LEGOFF', first_name: 'Jean', last_name: 'Le Goff')).to eq(true)
        expect(matches?('M OU MME LE', first_name: 'Van', last_name: 'Le')).to eq(true)
        expect(matches?('M VAN NGUYEN', first_name: 'Van', last_name: 'Le')).to eq(false)
        expect(matches?('M JOAO PEREIRA', first_name: 'João', last_name: 'Sá')).to eq(false)
      end

      it 'cannot tell without a last name' do
        expect(matches?('M JEAN', first_name: 'Jean', last_name: nil)).to be_nil
      end
    end

    context 'with a personne morale' do
      it 'leaves out legal forms and linking words' do
        expect(matches?("L'ATELIER DU BOIS", raison_sociale: 'SARL L’Atelier du bois')).to eq(true)
        expect(matches?('ATELIER BOIS', raison_sociale: "L'Atelier du bois")).to eq(true)
        expect(matches?("MOULIN\n2 CHEMIN DES PRES", raison_sociale: 'G.A.E.C. du Moulin')).to eq(true)
      end

      it 'reads dotted and spelled out legal forms' do
        expect(matches?('DES TILLEULS E.A.R.L.', raison_sociale: 'EARL des Tilleuls')).to eq(true)
        expect(matches?('GAEC DU MOULIN', raison_sociale: "Groupement agricole d'exploitation en commun du Moulin")).to eq(true)
        expect(matches?('SOCIETE A RESPONSABILITE LIMITEE DUPONT', raison_sociale: 'SARL Dupont')).to eq(true)
      end

      it 'reads a dotted legal form glued to the name' do
        expect(matches?('E.A.R.L.DUPONT', raison_sociale: 'EARL Dupont')).to eq(true)
        expect(matches?('G.A.E.C.MOULIN', raison_sociale: 'GAEC du Moulin')).to eq(true)
      end

      it 'reads every legal form, abbreviated or expanded' do
        RIB::LEGAL_FORMS.each do |abbreviation, expanded|
          expect(matches?("#{abbreviation} DUPONT", raison_sociale: "#{expanded} Dupont")).to eq(true), expanded
          expect(matches?("#{expanded} DUPONT", raison_sociale: "#{abbreviation} Dupont")).to eq(true), abbreviation
        end
      end

      it 'matches words glued differently, from 6 letters' do
        expect(matches?("LEROYMERLIN FRANCE\n1 RUE CHANZY", raison_sociale: 'Leroy Merlin France')).to eq(true)
        expect(matches?('LEROYMERLIN FRANCE', raison_sociale: 'Leroy Merlin de France')).to eq(true)
        expect(matches?('LEROYMERLIN DE FRANCE', raison_sociale: 'Leroy Merlin France')).to eq(true)
        expect(matches?('TAXI DUBOIS', raison_sociale: 'Ta Xi')).to eq(false)
      end

      it 'only glues whole words' do
        expect(matches?('DUPONTEL', raison_sociale: 'Dupont')).to eq(false)
        expect(matches?('LEROYMERLINS FRANCE', raison_sociale: 'Leroy Merlin France')).to eq(false)
      end

      it 'leaves out société, abbreviated or not' do
        expect(matches?('STE DUPONT', raison_sociale: 'Société Dupont')).to eq(true)
        expect(matches?('SOCIETE DUPONT', raison_sociale: 'Sté Dupont')).to eq(true)
      end

      it 'cannot tell without a raison sociale' do
        expect(matches?('GRTGAZ', raison_sociale: nil)).to be_nil
      end
    end

    it 'cannot tell when the account holder could not be read' do
      expect(matches?(nil, first_name: 'Jean', last_name: 'Dupont')).to be_nil
      expect(matches?(nil, raison_sociale: 'GRTGAZ')).to be_nil
    end
  end
end
