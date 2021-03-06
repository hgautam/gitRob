require 'net/smtp'
#require 'smtp-tls'
module Gitrob
  class CLI
    module Commands
      class Analyze < Gitrob::CLI::Command
        module Analysis
          def analyze_repositories
          # abort("Too many arguments!!!") unless @targets.length == 2
            repo_progress_bar do |progress|
              github_data_manager.owners.each do |owner|
                @db_owner = @db_assessment.save_owner(owner)
                thread_pool do |pool|
                  repositories_for_owner(owner).each do |repo|
                    #puts repo 
                    #puts @targets
                    #abort("Too many arguments!!!") unless @targets.length == 2
                    reponame = @targets[1]
                    #puts "repo to be scaned..."
                   # puts reponame
                    #name = "sonar-examples"
                    #repo1.to_s
                    #puts "============"
                    if ( repo.to_s =~ /#{reponame}/) 
                      #puts "match....."
                      #puts reponame
                      pool.process do
                        db_repo = @db_assessment.save_repository(repo, @db_owner)
                        blobs   = blobs_for_repository(repo)
                        analyze_blobs(blobs, db_repo, @db_owner, progress)
                        #break
                      end
                    end
                  end
                end
              end
            end
          end

          def analyze_blobs(blobs, db_repo, db_owner, progress)
            findings = 0
            blobs.each do |blob|
              db_blob = @db_assessment.save_blob(blob, db_repo, db_owner)
              Gitrob::BlobObserver.observe(db_blob)
              if db_blob.flags.count > 0
                findings += 1
                @db_assessment.findings_count += 1
                db_owner.findings_count += 1
                db_repo.findings_count += 1
              end
            end
            db_owner.save
            db_repo.save
            progress.increment
            report_findings(findings, db_repo, progress)
          rescue => e
            progress.error("#{e.class}: #{e.message}")
          end

          def report_findings(finding_count, repo, progress)
            return if finding_count.zero?
            files = finding_count == 1 ? "1 file" : "#{finding_count} files"
            progress.info(
              "Flagged #{files.to_s.light_yellow} " \
              "in #{repo.full_name.bold}")
            assessment = Sequel::Model.db.from(:assessments) 
            #gets the last record
            ass1 = assessment.select(:id).order(:id).last
            #splits the string {id=>45}
            @values =  ass1.to_s.split("=>")
            #deletes trailing }
            id = @values[1].delete "}"
            puts "id is..."
            puts id
            #ass2 = ass1.get(:id)
            #puts ass2
            send_email(id)
          end
          
          def send_email(id)
message = <<MESSAGE_END
From: Himanshu Gautam <hgautam@abc.com>
To: Himanshu Gautam <hgautam@abc.com>
MIME-Version: 1.0
Content-type: text/html
Subject: Gitrob Notification


Please click the following link to see Gitrob findings.

http://gitrob-dev-8848.phx01.dev.abcc3.com/assessments/#{id}/findings

MESSAGE_END
            Net::SMTP.start('atom.corp.abc.com', 25) do |smtp|
                 smtp.send_message message, 'hgautam@abc.com', 
                             'hgautam@abc.com'
            end
        end
      end

        def repo_progress_bar
          progress_bar(
            "Analyzing repositories...",
            :total => repository_count) do |progress|
            yield progress
          end
          sleep 0.1
        end

        def repositories_for_owner(owner)
          github_data_manager.repositories_for_owner(owner)
        end

        def blobs_for_repository(repo)
          github_data_manager.blobs_for_repository(repo)
        end

        def repository_count
          @github_data_manager.repositories.count
        end
      end
    end
  end
end
