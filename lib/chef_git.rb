require 'pry' # debug

module ChefGit
  REPO_PATH = '/var/chef/git'
end

require 'chef_git/expand_node_object'
require 'chef_git/role'
require 'chef_git/data_bag'

original_verbosity = $VERBOSE
begin
  $VERBOSE = nil # suppress warnings
  Chef::PolicyBuilder::ExpandNodeObject = ChefGit::ExpandNodeObject
  Chef::Role = ChefGit::Role
  Chef::Config[:data_bag_path] = File.join(ChefGit::REPO_PATH, 'data_bags')
  Chef::DataBag = ChefGit::DataBag
ensure
  $VERBOSE = original_verbosity
end
