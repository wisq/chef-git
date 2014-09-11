require 'pry' # debug

module ChefGit
end

require 'chef_git/expand_node_object'

Chef::PolicyBuilder::ExpandNodeObject = ChefGit::ExpandNodeObject
