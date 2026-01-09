# frozen_string_literal: true

require 'rubocop'
require 'rubocop/rspec/support'
require_relative '../../../../lib/cops/french_apostrophe'

RSpec.describe RuboCop::Cop::DS::FrenchApostrophe do
  subject(:cop) { described_class.new }

  it 'detects straight apostrophe in French text' do
    expect_offense(<<~RUBY)
      "l'adresse électronique"
      ^^^^^^^^^^^^^^^^^^^^^^^^ DS/FrenchApostrophe: Use modifier letter apostrophe ʼ (U+02BC) instead of ' (U+0027) or ' (U+2019) in French text
    RUBY

    expect_correction(<<~RUBY)
      "lʼadresse électronique"
    RUBY
  end

  it 'detects straight apostrophe with d'' do
    expect_offense(<<~RUBY)
      "d'un excellent organisme"
      ^^^^^^^^^^^^^^^^^^^^^^^^^^ DS/FrenchApostrophe: Use modifier letter apostrophe ʼ (U+02BC) instead of ' (U+0027) or ' (U+2019) in French text
    RUBY

    expect_correction(<<~RUBY)
      "dʼun excellent organisme"
    RUBY
  end

  it 'detects straight apostrophe with n'' do
    expect_offense(<<~RUBY)
      "n'est pas valide"
      ^^^^^^^^^^^^^^^^^^ DS/FrenchApostrophe: Use modifier letter apostrophe ʼ (U+02BC) instead of ' (U+0027) or ' (U+2019) in French text
    RUBY

    expect_correction(<<~RUBY)
      "nʼest pas valide"
    RUBY
  end

  it 'detects aujourd''hui' do
    expect_offense(<<~RUBY)
      "aujourd'hui"
      ^^^^^^^^^^^^^ DS/FrenchApostrophe: Use modifier letter apostrophe ʼ (U+02BC) instead of ' (U+0027) or ' (U+2019) in French text
    RUBY

    expect_correction(<<~RUBY)
      "aujourdʼhui"
    RUBY
  end

  it 'ignores already correct modifier letter apostrophes' do
    expect_no_offenses(<<~RUBY)
      "lʼadresse électronique"
    RUBY
  end

  it 'ignores strings without French contractions' do
    expect_no_offenses(<<~RUBY)
      "user.method_name"
    RUBY
  end

  it 'ignores apostrophes not matching French patterns' do
    expect_no_offenses(<<~RUBY)
      "Can't add row"
    RUBY
  end

  it 'handles multiple French contractions in one string' do
    expect_offense(<<~RUBY)
      "qu'il n'a plus d'utilisateurs"
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ DS/FrenchApostrophe: Use modifier letter apostrophe ʼ (U+02BC) instead of ' (U+0027) or ' (U+2019) in French text
    RUBY

    expect_correction(<<~RUBY)
      "quʼil nʼa plus dʼutilisateurs"
    RUBY
  end
end
