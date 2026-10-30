# frozen_string_literal: true

class RIB
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :account_holder, :string
  attribute :bank_name, :string
  attribute :bic, :string
  attribute :iban, :string

  CIVILITIES = %w[M MR MME MLLE MONSIEUR MADAME].freeze
  LEGAL_FORMS = {
    'SA' => 'societe anonyme',
    'SAS' => 'societe par actions simplifiee',
    'SASU' => 'societe par actions simplifiee unipersonnelle',
    'SARL' => 'societe a responsabilite limitee',
    'EURL' => 'entreprise unipersonnelle a responsabilite limitee',
    'EIRL' => 'entrepreneur individuel a responsabilite limitee',
    'EI' => 'entrepreneur individuel',
    'SNC' => 'societe en nom collectif',
    'SCI' => 'societe civile immobiliere',
    'SCP' => 'societe civile professionnelle',
    'SCOP' => 'societe cooperative et participative',
    'SELARL' => 'societe d exercice liberal a responsabilite limitee',
    'SELAS' => 'societe d exercice liberal par actions simplifiee',
    'GIE' => 'groupement d interet economique',
    'EARL' => 'exploitation agricole a responsabilite limitee',
    'GAEC' => 'groupement agricole d exploitation en commun',
    'SCEA' => 'societe civile d exploitation agricole',
    'GFA' => 'groupement foncier agricole',
    'CUMA' => 'cooperative d utilisation de materiel agricole',
    'SICA' => 'societe d interet collectif agricole',
    'STE' => 'societe',
  }.freeze
  LINKING_WORDS = %w[de du des la le les l d et a au aux en].freeze

  IGNORED_WORDS = (CIVILITIES + LEGAL_FORMS.keys + LINKING_WORDS).map(&:downcase).to_set.freeze
  # A person's name keeps its particles: "Le Goff", "De La Fontaine".
  IGNORED_PERSON_WORDS = CIVILITIES.map(&:downcase).to_set.freeze
  # The longest first, so that SASU is not read as SAS followed by "unipersonnelle".
  EXPANDED_LEGAL_FORMS = /\b(?:#{LEGAL_FORMS.values.sort_by(&:size).reverse.join('|')})\b/

  # Below this, a glued name could show up inside an unrelated word.
  MIN_GLUED_NAME_LENGTH = 6

  # "M OU MME DUPONT", "MONSIEUR ET MADAME DUPONT"
  JOINT_ACCOUNT = /\b(?:#{CIVILITIES.join('|')})\b.*\b(?:ou|et) (?:#{CIVILITIES.join('|')})\b/i

  def to_h
    { account_holder:, bank_name:, bic:, iban: }
  end

  # A personne morale is compared on its raison sociale, legal forms and linking
  # words aside. A personne physique, civilities aside, on its first first name
  # and last name, banks printing one first name:
  #   "Xavier Jean-Marie" "Julien" ~ "M XAVIER JULIEN"
  # or on its last name alone for a joint account, or without a first name:
  #   "Jean" "Dupont" ~ "M OU MME DUPONT"
  def account_holder_matches?(raison_sociale: nil, first_name: nil, last_name: nil)
    return if account_holder.blank?

    if raison_sociale.present?
      return contains?(normalize_raison_sociale(account_holder), normalize_raison_sociale(raison_sociale))
    end

    # we check only the first first_name
    first_name = first_name.to_s.split.first

    holder, first_name, last_name = [account_holder, first_name, last_name]
      .map { normalize_person(it.to_s) }

    # not enough information
    return if last_name.empty?

    return contains?(holder, last_name) if joint_account?

    contains?(holder, first_name + last_name)
  end

  private

  # Every word of the name is in the holder, in any order:
  #   "Jean-Pierre Lefèvre" ~ "MME LEFEVRE JEAN PIERRE\n12 RUE …"
  #   "L'Atelier du bois"   ~ "ATELIER BOIS"
  # or the glued name is consecutive words of the holder, glued too:
  #   "Leroy Merlin France" ~ "LEROYMERLIN FRANCE", not ~ "LEROYMERLINS FRANCE"
  def contains?(holder, name)
    return false if name.empty?

    glued_name = name.join

    name.all? { holder.include?(it) } ||
      (glued_name.size >= MIN_GLUED_NAME_LENGTH && glued_words(holder).include?(glued_name))
  end

  # ["leroymerlin", "france"] -> ["leroymerlin", "france", "leroymerlinfrance"]
  def glued_words(words)
    (1..words.size).flat_map { |size| words.each_cons(size).map(&:join) }
  end

  def joint_account? = to_downcased_alpha_num(account_holder).match?(JOINT_ACCOUNT)

  # "E.A.R.L. des Tilleuls"                                -> ["tilleuls"]
  # "Groupement agricole d'exploitation en commun du Moulin" -> ["moulin"]
  def normalize_raison_sociale(text)
    to_downcased_alpha_num(text)
      .gsub(EXPANDED_LEGAL_FORMS, ' ')
      .split
      .reject { IGNORED_WORDS.include?(it) }
  end

  # "M Jean Le Goff" -> ["jean", "le", "goff"]
  def normalize_person(text)
    to_downcased_alpha_num(text).split.reject { IGNORED_PERSON_WORDS.include?(it) }
  end

  # "E.A.R.L. d'Épône" -> "earl d epone"
  def to_downcased_alpha_num(text)
    I18n.transliterate(text).downcase
      .gsub(/\b(?:[a-z]\.){2,}/) { "#{it.delete('.')} " } # e.a.r.l.dupont => earl dupont
      .scan(/[a-z0-9]+/) # 'earl chose' -> ['earl', 'chose']
      .join(' ')
  end
end
