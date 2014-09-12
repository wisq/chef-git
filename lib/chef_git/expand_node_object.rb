require 'chef/policy_builder/expand_node_object'
require 'librarian/chef/cli'
require 'pathname'

class ChefGit::ExpandNodeObject < Chef::PolicyBuilder::ExpandNodeObject
  class CommandFailed < StandardError
    attr_reader :command, :status

    def initialize(command, status)
      @command = command
      @status  = status
    end

    def message
      title = @command.join(' ').inspect
      return "#{title} exited with status #{status.exitstatus}" if status.exited?
      return "#{title} died with signal #{status.termsig}" if status.signalled?
      "#{title} died of unknown causes: #{status.inspect}"
    end
  end


  def check_out_git
    return if @git_repo
    repo = Pathname.new('/var/chef/git')
    Dir.chdir(repo) do
      git('fetch', 'origin')
      git('reset', '--hard')
      git('clean', '-fd')
      git('checkout', "origin/#{@node.chef_environment}")

      Librarian::Chef::Cli.with_environment { Librarian::Chef::Cli.start(['install']) }
    end
    @git_repo = repo

    Chef::Config[:cookbook_path] = [
      @git_repo + 'cookbooks',
      @git_repo + 'tmp/librarian/cookbooks'
    ].map(&:to_s)
    Chef::Config[:role_path] = (@git_repo + 'roles').to_s
  end

  def setup_run_context(specific_recipes=nil)
    check_out_git

    # Copied from chef, because we need to act like :solo = true but not actually set it.
    Chef::Cookbook::FileVendor.on_create { |manifest| Chef::Cookbook::FileSystemFileVendor.new(manifest, Chef::Config[:cookbook_path]) }
    cl = Chef::CookbookLoader.new(Chef::Config[:cookbook_path])
    cl.load_cookbooks
    cookbook_collection = Chef::CookbookCollection.new(cl)
    run_context = Chef::RunContext.new(node, cookbook_collection, @events)

    run_context.load(@run_list_expansion)
    if specific_recipes
      specific_recipes.each do |recipe_file|
        run_context.load_recipe_file(recipe_file)
      end
    end
    run_context
  end

  def expand_run_list
    check_out_git

    @run_list_expansion = node.expand!('disk')

    @expanded_run_list_with_versions = @run_list_expansion.recipes.with_version_constraints_strings
    @run_list_expansion
  end

  private

  def git(*args)
    command('git', *args)
  end

  def command(*command)
    system(*command)
    raise CommandFailed.new(command, $?) unless $?.success?
  end

  def resolve_file_paths(cookbook, cookbook_path)
    Chef::CookbookVersion::COOKBOOK_SEGMENTS.each do |segment|
      paths = cookbook.manifest[segment].map { |mani| (cookbook_path + mani['path']).to_s }

      if segment.to_sym == :recipes
        cookbook.recipe_filenames = paths
      elsif segment.to_sym == :attributes
        cookbook.attribute_filenames = paths
      else
        cookbook.segment_filenames(segment).replace(paths)
      end
    end
  end
end
