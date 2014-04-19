require "git/output"
require "git/tail/commit"

module Git
  module Tail

    # Encapsulates all tailing tasks and performs them in the proper order.
    class Runner
      include Git::Output

      # Start time of the current tail run.
      attr_reader :now

      # Path of target repo to operate on.
      attr_reader :repo

      # Starting point of commit history to keep. Any absolute or relative
      # date string that `git log --since` can parse is acceptable.
      attr_reader :since

      # Branches specified on command line. (Runs on all branches if empty.)
      attr_reader :branches


      # @param [String]
      # @param [Hash] options See `git tail --help`
      def initialize(options)
        @now = Time.now
        @since = options[:since]
        @branches = options[:branches] || []
      end

      def run
        out "Truncating history before #{since_time}",
          "Checking local branches..."
        get_local_branches if branches.empty?
        branches.each {|branch| clean_local branch}
        out "Cleaning and repacking objects..."
        Git.command 'reflog', ['expire', '--expire=all', '--all']
        Git.command 'gc', ['--aggressive', '--prune=all']

      end

      def clean_local(branch)
        out 2, "#{branch}:"
        old_log = Git.command 'log', [min_age, '--format=fuller', branch]
        new_log = Git.command 'log', [max_age, '--format=fuller', branch]

        if old_log.empty?
          out :detail, 2, "No commits prior to cutoff date. Skipping."
        else
          old_log_entries = old_log.split /(?=commit [0-9a-f]{40})/   # Lookahead assertions FTW
          new_log_entries = new_log.split /(?=commit [0-9a-f]{40})/   # Lookahead assertions FTW
          new_commits = new_log_entries.collect {|entry| Commit.new(entry)}

          out :detail, 4, "Truncating #{old_log_entries.length} commits..."
          old_base = Commit.new(old_log_entries.first)

          tree = Git.command 'rev-parse', "#{old_base.hash}^{tree}"
          new_base = Git.command 'commit-tree', ['-m', "\"#{old_base.message}\"".squeeze('"'), tree],
            'GIT_COMMITTER_NAME'  => old_base.committer_name,
            'GIT_COMMITTER_EMAIL' => old_base.committer_email,
            'GIT_COMMITTER_DATE'  => old_base.committer_date,
            'GIT_AUTHOR_NAME'     => old_base.author_name,
            'GIT_AUTHOR_EMAIL'    => old_base.author_email,
            'GIT_AUTHOR_DATE'     => old_base.author_date
          Git.command 'replace', ['-f', old_base.hash, new_base]

          # Now rewrite the history to make the replacement permanent...
          Git.command 'filter-branch', ['--tag-name-filter', 'cat', branch]

          # ...And get rid of the replacement now that we no longer need it.
          Git.command 'update-ref -d', ["refs/replace/#{old_base.hash}", new_base]

          # Also get rid of any refs that pointed to the old HEAD commit, so we can gc it.
          delete_refs new_commits.first.hash

        end
      end

    private

      def max_age
        @max_age ||= Git.command 'rev-parse', "--since='#{since}'"
      end

      def min_age
        max_age.sub('max','min')
      end

      def since_time
        Time.at max_age[/\d+/].to_i
      end

      def get_local_branches
        git_branches = Git.command 'branch', %w(--list --no-color)
        branch_names = git_branches.split($/)
        branch_names.each do |branch|
          branches << branch[/\s*\*?\s*(.*)/, 1]
        end
      end

      def delete_refs(commit)
        all_refs = Git.command 'for-each-ref'
        all_refs.scan /^#{commit}\scommit\s+(.+)$/ do |refgroup|
          if ref = refgroup[0]
            out :detail, 4, "Deleting old ref #{ref}"
            Git.command 'update-ref',  ['-d', ref]
          end
        end
      end

    end
  end
end
