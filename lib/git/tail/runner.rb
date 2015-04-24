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

      # If true, alias new commits to old hashes using 'git replace'
      attr_reader :replace

      # Captures the original and rewritten commit hashes for 'git replace'
      attr_reader :commit_map


      # @param [String]
      # @param [Hash] options See `git tail --help`
      def initialize(options)
        @now = Time.now
        @since = options[:since]
        @replace = options[:replace]
        @branches = options[:branches] || []
        @commit_map = {}
      end

      def run
        out "Truncating history before #{since_time}",
          "Checking local branches..."
        get_local_branches if branches.empty?
        branches.each {|branch| clean_local branch}

        out "Cleaning and repacking objects..."
        repack

        if replace
          out "Aliasing new commit hashes to old ones..."
          branches.each {|branch| update_commit_map branch}
          replace_commit_hashes commit_map.values
        end

      end

      def clean_local(branch)
        out 2, "#{branch}:"
        tip_hash = Git.command 'rev-parse', [branch]

        # commits older than and including cutoff
        old_log = Git.command 'log', [min_age, '--format=raw', branch]
        old_log_entries = old_log.split /(?=commit [0-9a-f]{40})/   # Lookahead assertions FTW

        # commits newer than and including cutoff
        new_log = Git.command 'log', [max_age, '--format=raw', branch]
        new_log_entries = new_log.split /(?=commit [0-9a-f]{40})/

        # If the cutoff time is the same as one of the commit times, this
        # commit will be in both new_log_entries and old_log_entries. So
        # make sure it's only in one.
        new_log_entries.pop if new_log_entries.last == old_log_entries.first

        if old_log_entries.count <= 1
          out :detail, 2, "No commits prior to cutoff date. Skipping."
        else
          build_commit_map(branch) if replace

          out :detail, 4, "Truncating #{old_log_entries.length} commits..."
          old_base = Commit.new(old_log_entries.first)

          tree = Git.command 'rev-parse', "#{old_base.hash}^{tree}"
          new_base = Git.command 'commit-tree',
            ['-m', "\"#{old_base.message}\"".squeeze('"'), tree],
            old_base.env

          Git.command 'replace', ['-f', old_base.hash, new_base]

          # Now rewrite the history to make the replacement permanent...
          Git.command 'filter-branch', ['--tag-name-filter', 'cat', branch]

          # ...And get rid of the replacement now that we no longer need it.
          Git.command 'update-ref -d', ["refs/replace/#{old_base.hash}", new_base]

          # Also get rid of any refs that pointed to the old HEAD commit, so we can gc it.
          delete_refs tip_hash

        end
      end

      def repack
        Git.command 'reflog', ['expire', '--expire=all', '--all']
        Git.command 'gc', ['--aggressive', '--prune=all']
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

      def each_commit(branch)
        log = Git.command 'log', [max_age, '--format=raw', branch]
        log_entries = log.split /(?=commit [0-9a-f]{40})/
        log_entries.each do |entry|
          commit = Commit.new(entry)
          yield commit
        end
      end

      def build_commit_map(branch)
        out :detail, 4, "Capturing recent commits for aliasing..."
        each_commit(branch) do |commit|
          commit_map[commit.key] = [commit.hash, nil]
        end
      end

      def update_commit_map(branch)
        each_commit(branch) do |commit|
          if pair = commit_map[commit.key]
            pair[1] = commit.hash
          end
        end
      end

      def replace_commit_hashes(commit_pairs)
        commit_pairs.each do |pair|
          old_hash, new_hash = *pair
          Git.command 'replace', ['-f', old_hash, new_hash]
        end
      end


    end
  end
end
