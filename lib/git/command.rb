require 'childprocess'
require 'git/output'

module Git
  class CommandError < StandardError
  end

  # Git::Tail runs a lot of external Git commands. This class wraps them
  # in a structure that makes for easier process management, output and
  # error capture, and rendering to the user.
  class Command
    include Output

    class << self
      # If true, stdout and stderr from commands are forwarded to the
      # script STDOUT and STDERR as well as being captured.
      attr_accessor :verbose
    end

    attr_reader :command, :arguments, :environment

    # Set after {#run} completes.
    attr_reader :stdout, :stderr, :status

    # Sets up the command to be run, with options hash.
    #
    # @note Don't specify 'git' on the command name; it will be prefixed
    # to the command automatically.
    #
    # @param [String, Symbol] cmd Git command to run (i.e. `git <cmd>`)
    # @param [Array] args Options and arguments in order
    # @param [Hash] env Environment variables to set on execution
    def initialize(cmd, args=[], env={})
      @command, @arguments, @environment = cmd, Array(args), env
      @stdout, @stderr = "", ""
    end

    # Invokes the command and waits for it to finish. The *stdout*,
    # *stderr* and *status* attributes are set upon completion.
    #
    # @param [Boolean] raise_on_error Raise a CommandError with stderr on non-zero exit status
    # @return [String] Same as *stdout* attribute.
    # @raise [CommandError] Captures results on failure unless `raise_on_error` is false
    def run(raise_on_error = true)
      outpipe, outthread = verbose_pipe(stdout, :cmdout)
      errpipe, errthread = verbose_pipe(stderr, :cmderr)

      process = ChildProcess.build *command_array
      process.environment.merge! environment
      process.io.stdout = outpipe
      process.io.stderr = errpipe
      out :cmdline, 2, full_command if verbose?

      process.start
      @status = process.wait
      outpipe.close
      errpipe.close
      outthread.join
      errthread.join
      out(nil) if verbose?   # Blank lines make for easier screen reading

      if raise_on_error and process.crashed?
        raise CommandError.new stderr
      end

      stdout.chomp
    end

    # Presents the full command line as a string for the user
    def full_command
      command_array.join(' ')
    end

  private
    def command_array
      ['git'] + command.split(' ') + arguments
    end

    def verbose?
      self.class.verbose
    end

    def verbose_pipe(destination, format)
      reader, writer = IO::pipe
      thread = Thread.new do
        while line = reader.gets
          destination << line
          out format, 2, line.chomp if verbose?
        end
        reader.close
      end
      [writer, thread]
    end
  end

  # Runs the given Git subcommand and sends results to standard output
  # or error. Kills the program if the command fails.
  # @param (see Command#initialize)
  def self.command(cmd, args=[], env={})
    command = Command.new cmd, args, env
    command.run

  rescue CommandError => e
    err "Command `git #{command.command}` failed with status #{command.status}:",
      2, :cmderr, e.message
    exit command.status
  end

end
