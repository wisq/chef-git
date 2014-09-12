require 'chef/role'

class ChefGit::Role < Chef::Role
  def self.from_disk(name, *args)
    file = name.gsub('--', '/') + ".rb"
    path = Array(Chef::Config[:role_path]).map { |dir| File.join(dir, file) }.detect { |f| File.exist?(f) }
    raise "#{file.inspect} not found in :role_path #{role_path.inspect}" unless path

    role = new
    role.name(name)
    role.from_file(path)
    role
  end
end
