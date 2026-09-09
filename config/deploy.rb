# frozen_string_literal: true

require 'mina/bundler'
require 'mina/git'
require 'mina/rails'
require 'mina/rbenv'

SHARED_WEBSERVER_FILE_NAME = 'i_am_a_webserver'
# Basic settings:
#   domain        - The hostname to SSH to.
#   deploy_to     - Path to deploy into.
#   repository    - Git repo to clone from. (needed by mina/git)
#   branch        - Branch name to deploy. (needed by mina/git)
#
# Advanced settings:
#   forward_agent - SSH forward_agent
#   user          - Username in the server to SSH to
#   shared_dirs   - Manually create these paths in shared/ on your server.
#                   They will be linked in the 'deploy:link_shared_paths' step.

deploy_to = '/var/www/ds'
shared_dirs = [
  'log',
  'sockets',
  'tmp/cache',
  'tmp/pids',
  'vendor/bundle',
]

set :domain, ENV.fetch('DOMAINS')
set :deploy_to, deploy_to
# rubocop:disable DS/ApplicationName
set :repository, 'https://github.com/demarche-numerique/demarche.numerique.gouv.fr.git'
# rubocop:enable DS/ApplicationName
set :branch, ENV.fetch('BRANCH')
set :forward_agent, true
set :user, 'ds'
set :shared_dirs, shared_dirs
set :rbenv_path, "/home/ds/.rbenv/bin/rbenv"

puts "Deploy to #{ENV.fetch('DOMAINS')}, branch: #{ENV.fetch('BRANCH')}"

# This task is the environment that is loaded for most commands, such as
# `mina deploy` or `mina rake`.
task :setup do
  shared_dirs.each do |dir|
    command %[mkdir -p "#{deploy_to}/shared/#{dir}"]
    command %[chmod g+rx,u+rwx "#{deploy_to}/shared/#{dir}"]
  end
end

namespace :yarn do
  desc "Install package dependencies using yarn."
  task :install do
    # DSFR_ACCEPT_LICENSE: @gouvfr/dsfr refuses to install until its terms of use
    # are accepted. We are a State service on a .gouv.fr domain, so we accept them
    # on the machines that build our own deployment, rather than committing a
    # .dsfr.yml that would answer for every instance of this codebase.
    # See doc/DEPLOYMENT.md.
    command %{
      echo "-----> Installing package dependencies using yarn"
      #{echo_cmd %[DSFR_ACCEPT_LICENSE=1 yarn install --non-interactive]}
    }
  end
end

namespace :jobs_schedule do
  desc "Run jobs_schedule tasks."
  task :run do
    command %{
      echo "-----> Running jobs_schedule"
      #{echo_cmd %[bundle exec rake jobs:schedule]}
    }
  end
end

namespace :service do
  desc "Restart puma"
  task :restart_puma do
    webserver_file_path = File.join(deploy_to, 'shared', SHARED_WEBSERVER_FILE_NAME)

    command %{
      echo "-----> Restarting puma service"
      #{echo_cmd %[test -f #{webserver_file_path} && sudo systemctl restart puma]}
    }
  end

  desc "Reload nginx"
  task :reload_nginx do
    webserver_file_path = File.join(deploy_to, 'shared', SHARED_WEBSERVER_FILE_NAME)

    command %{
      echo "-----> Reloading nginx service"
      #{echo_cmd %[test -f #{webserver_file_path} && sudo systemctl reload nginx]}
    }
  end
end

desc "Deploys the current version to the server."
task :deploy do
  command 'export PATH=$PATH:/home/ds/.rbenv/bin:/home/ds/.rbenv/shims'
  command 'source /home/ds/.profile'
  # increase db timeout to 5 minutes to allow long migration
  command 'export PG_STATEMENT_TIMEOUT=300000'

  deploy do
    # Put things that will set up an empty directory into a fully set-up
    # instance of your project.

    invoke :'git:clone'
    invoke :'deploy:link_shared_paths'
    invoke :'bundle:install'
    invoke :'yarn:install'
    invoke :'rails:db_migrate'
    invoke :'rails:assets_precompile'

    on :launch do
      invoke :'service:restart_puma'
      invoke :'service:reload_nginx'
      invoke :'deploy:cleanup'
    end
  end
end

task :post_deploy do
  command 'export PATH=$PATH:/home/ds/.rbenv/bin:/home/ds/.rbenv/shims'
  command 'source /home/ds/.profile'
  command 'cd /home/ds/current'

  invoke :'jobs_schedule:run'
end
