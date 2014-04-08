module Git
  module Tail
    # Represents a commit in the repo with all relevant metadata.
    # Input is the string from "git log --format=fuller"
    class Commit
      attr_reader :hash, :message,
        :committer_name, :committer_email, :committer_date,
        :author_name, :author_email, :author_date

      def initialize(log)
        @hash = log[/commit ([0-9a-f]{40})/, 1]
        @message = log[/\n\n(.+)/m, 1].gsub(/^ +/, '').rstrip
        @committer_name  = log[/Commit:\s+(.+) <(.+)>/, 1]
        @committer_email = log[/Commit:\s+(.+) <(.+)>/, 2]
        @committer_date  = log[/CommitDate:\s+(.+)/, 1]
        @author_name     = log[/Author:\s+(.+) <(.+)>/, 1]
        @author_email    = log[/Author:\s+(.+) <(.+)>/, 2]
        @author_date     = log[/AuthorDate:\s+(.+)/, 1]
      end

    end
  end
end
