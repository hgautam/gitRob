module Gitrob
  class CLI
    module Commands
      class Analyze < Gitrob::CLI::Command
        module Gathering
          def gather_owners
            task("Gathering targets...") do
              thread_pool do |pool|
                github_data_manager.gather_owners(pool)
              end
            end
            fatal("No users or organizations " \
              "found; exiting") if owner_count.zero?
          end

          def gather_repositories
            make_repo_gathering_progress_bar do |progress|
              thread_pool do |pool|
                github_data_manager
                  .gather_repositories(pool) do |owner, repositories|
                  repository_gathering_update(owner, repositories, progress)
                end
              end
            end
            fatal("No repositories found; exiting") if repo_count.zero?
            info "Gathered #{repo_count} repositories"
            @myrepos = github_data_manager.get_repositories("hgautam")
            #puts "my repos are... " 
            #puts @myrepos
            puts "targets are..."
            puts @targets
            @repos = github_data_manager.repositories_for_owner(@targets[0])
            puts @repos
          end

          def github_data_manager
            #puts "inside data manager"
            #puts @targets
            #puts "deleting last index of the array"
            @targets.delete_at(1)
            #puts "array after deletion"
            #puts @targets
            unless @github_data_manager
              @github_data_manager = Gitrob::Github::DataManager.new(
                @targets, github_client_manager
              )
            end
            @github_data_manager
          end

          def github_client_manager
            unless @github_client_manager
              @github_client_manager = Gitrob::Github::ClientManager.new(
                client_manager_configuration
              )
            end
            @github_client_manager
          end

          def client_manager_configuration
            {
              :endpoint      => @options[:endpoint],
              :site          => @options[:site],
              :ssl           => {
                :verify => @options[:verify_ssl]
              },
              :access_tokens => github_access_tokens
            }
          end

          def github_access_tokens
            if @options[:access_tokens]
              @options[:access_tokens].gsub("\n", ",").split(",").map(&:strip)
            else
              Gitrob::CLI.configuration["github_access_tokens"]
            end
          end

          def make_repo_gathering_progress_bar
            total = github_data_manager.owners.count
            progress_bar(
              "Gathering repositories from #{total} targets...",
              :total => total
            ) do |progress|
              yield progress
            end
            sleep 0.1
          end

          def repo_count
            github_data_manager.repositories.count
          end

          def owner_count
            github_data_manager.owners.count
          end

          def repository_gathering_update(owner, repositories, progress_bar)
            count = repositories.count
            progress_bar.increment
            return if count.zero?
            gathered = Gitrob::Utils.pluralize(
              count,
              "repository",
              "repositories"
            )
            progress_bar.info("Gathered #{gathered} " \
                          "from #{owner['login'].bold}")
          end
        end
      end
    end
  end
end
