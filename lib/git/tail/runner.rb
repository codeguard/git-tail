require "git/output"

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
      end

      def clean_local(branch)
        out 2, "#{branch}:"
        old_log = Git.command 'log', [min_age, branch], :format => 'fuller'
        # new_log = Git.command 'log', [max_age, branch], :format => 'fuller'

        if old_log.empty?
          out :detail, 2, "No commits prior to cutoff date. Skipping."
        else
          # Lookahead assertions FTW
          old_commits = old_log.split /(?=commit [0-9a-f]{40})/

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
        git_branches = Git.command 'branch', nil, :list => true, :color => false
        branch_names = git_branches.split($/)
        branch_names.each do |branch|
          branches << branch[/\s*\*?\s*(.*)/, 1]
        end
      end
    end
  end
end
