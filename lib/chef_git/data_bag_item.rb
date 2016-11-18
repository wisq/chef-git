require 'chef/encrypted_data_bag_item'

# We are forcing chef solo mode so that we use the data bags from git instead of trying to use the server
# https://github.com/chef/chef/blob/db57131ad383076391b9df32d5e9989cfb312d58/lib/chef/data_bag.rb#L119-L144

class ChefGit::DataBagItem < Chef::DataBag

  def self.load(data_bag, name)
    Chef::Config[:solo_legacy_mode] = chef_git_use_solo?(data_bag, name)
    result = super
    Chef::Config[:solo_legacy_mode] = false
    return result
  end

  def self.chef_git_use_solo?(data_bag, name)
    item_file = File.join(Chef::Config[:data_bag_path], data_bag, "#{name}.json")
    raw_data = Chef::JSONCompat.from_json(IO.read(item_file))
    !ChefGitDataBagEncryptedChecker.encrypted?(raw_data)
  end

  module ChefGitDataBagEncryptedChecker
    extend Chef::EncryptedDataBagItem::CheckEncrypted
  end
end
