module Git
  module Tail
    # Represents a commit in the repo with all relevant metadata.
    # Input is the string from "git log --format=raw"
    class Commit
      attr_reader :hash, :tree, :parent, :message,
        :author_name, :author_email, :author_date,
        :committer_name, :committer_email, :committer_date

      def initialize(log)
        @hash = log[/^commit ([0-9a-f]{40})/, 1]
        @tree = log[/^tree ([0-9a-f]{40})/, 1]
        @parent = log[/^parent ([0-9a-f]{40})/, 1]

        if log =~ /^author (.+) <(.+)> (\d+ ([+-]?\d{4})?)/
          @author_name, @author_email, @author_date = $1, $2, $3
        end

        if log =~ /^committer (.+) <(.+)> (\d+ ([+-]?\d{4})?)/
          @committer_name, @committer_email, @committer_date = $1, $2, $3
        end

        @message = log[/\n\n(.+)/m, 1].gsub(/^ +/, '').rstrip
      end

      # Two commits are considered the same if they have the same tree and
      # the same commit and author metadata. This is how we re-identify
      # commits after their hash IDs have been rewritten.
      def key
        [tree, author_name, author_email, author_date, committer_name, committer_email, committer_date]
      end

      # Returns a hash of string keys and values for the commit and author
      # metadata, suitable for setting environment variables.
      def env
        {
          'GIT_COMMITTER_NAME'  => committer_name,
          'GIT_COMMITTER_EMAIL' => committer_email,
          'GIT_COMMITTER_DATE'  => committer_date,
          'GIT_AUTHOR_NAME'     => author_name,
          'GIT_AUTHOR_EMAIL'    => author_email,
          'GIT_AUTHOR_DATE'     => author_date
        }
      end


    end
  end
end
