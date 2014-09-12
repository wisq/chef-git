require 'chef/role'

class ChefGit::Role < Chef::Role
  def self.from_disk(name, *args)
    path = File.join(Chef::Config[:role_path], name.gsub('--', '/') + ".rb")
    role = new
    role.name(name)
    role.from_file(path)
    role
  end
end
