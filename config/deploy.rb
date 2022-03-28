# config valid for current version and patch releases of Capistrano
lock "~> 3.17.0"

set :application, "nft-hunter"
set :repo_url, "git@github.com:brtr/nft-hunter.git"

# Default branch is :master
ask :branch, `git rev-parse --abbrev-ref HEAD`.chomp

# Default deploy_to directory is /var/www/my_app_name
set :deploy_to, "/home/deploy/app/nft-hunter"

set :linked_files, fetch(:linked_files, []).push('config/application.yml')
set :linked_dirs, fetch(:linked_dirs, []).push('log', 'tmp/pids', 'tmp/cache', 'tmp/sockets', 'vendor/bundle', 'public/system', 'public/uploads')

set :pty, false
set :rails_env, fetch(:staging)
set :rbenv_type, :user # or :system, depends on your rbenv setup
set :rbenv_ruby, '3.0.1'
set :rbenv_prefix, "RBENV_ROOT=#{fetch(:rbenv_path)} RBENV_VERSION=#{fetch(:rbenv_ruby)} #{fetch(:rbenv_path)}/bin/rbenv exec"
set :rbenv_map_bins, %w{rake gem bundle ruby rails}
set :bundler_path, "/home/deploy/.rbenv/shims/bundle"
# for assets
set :assets_role, :web
set :keep_assets, 2
