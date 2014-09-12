require 'pry' # debug

module ChefGit
end

require 'chef_git/expand_node_object'
require 'chef_git/role'

Chef::PolicyBuilder::ExpandNodeObject = ChefGit::ExpandNodeObject
Chef::Role = ChefGit::Role
