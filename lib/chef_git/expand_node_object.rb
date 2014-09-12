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
  end

  def expand_run_list
    check_out_git
    Chef::Config[:role_path] = (@git_repo + 'roles').to_s

    @run_list_expansion = node.expand!('disk')

    @expanded_run_list_with_versions = @run_list_expansion.recipes.with_version_constraints_strings
    @run_list_expansion
  end

  def sync_cookbooks
    check_out_git

    # -- Copypasta from real chef: --
    begin
      events.cookbook_resolution_start(@expanded_run_list_with_versions)
      cookbook_hash = api_service.post("environments/#{node.chef_environment}/cookbook_versions",
                                      {:run_list => @expanded_run_list_with_versions})
    rescue Exception => e
      # TODO: wrap/munge exception to provide helpful error output
      events.cookbook_resolution_failed(@expanded_run_list_with_versions, e)
      raise
    else
      events.cookbook_resolution_complete(cookbook_hash)
    end
    # -- end copypasta --

    cookbooks = @git_repo + 'cookbooks'
    librarian_cookbooks = @git_repo + 'tmp/librarian/cookbooks'

    cookbook_hash.each do |name, book|
      resolve_file_paths(book, [cookbooks + name, librarian_cookbooks + name].detect(&:exist?))
    end

    Chef::Config[:cookbook_path] = cookbooks.to_s

    cookbook_hash
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
