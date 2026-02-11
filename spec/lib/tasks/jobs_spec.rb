# frozen_string_literal: true

require 'rake'
TPS::Application.load_tasks if Rake::Task.tasks.empty?

describe 'jobs' do
  describe 'schedule' do
    subject { Rake::Task['jobs:schedule'].invoke }
    it 'runs' do
      expect { subject }.not_to raise_error
    end
  end
end
