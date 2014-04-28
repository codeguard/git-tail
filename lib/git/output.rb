require 'rainbow'

STDOUT.sync = true
STDERR.sync = true

module Git

  # Convenience methods for sending the right information to stdout or
  # stderr, with colors to make it easily scannable on terminals
  module Output
    OUT_COLORS = {
      :default => [:green, :bright],
      :detail => :white,
      :cmdline => :yellow,
      :cmdout => :white,
      :cmderr => :red
    }

    ERR_COLORS = {
      :default => [:red, :bright],
      :detail => :cyan,
      :cmdline => :yellow,
      :cmdout => :cyan,
      :cmderr => :red
    }

    # If true, colorize output regardless of terminal status.
    # If false, do not colorize regardless of terminal status.
    # If not set, use the default value of {Rainbow.enabled}.
    def self.color
      Rainbow.enabled
    end

    # Override default terminal detection behavior.
    def self.color=(val)
      Rainbow.enabled = val
    end

    # Sends all of the given strings to STDOUT. Symbols change the color
    # for following strings, using the type mapping from {OUT_COLORS}.
    def out(*elements)
      elements.unshift :default
      strings = colorize(elements, OUT_COLORS)
      strings.each {|s| STDOUT.puts s}
    end

    # Sends all of the given strings to STDERR. Symbols change the color
    # for following strings, using the type mapping from {ERR_COLORS}.
    def err(*elements)
      elements.unshift :default
      strings = colorize(elements, ERR_COLORS)
      strings.each {|s| STDERR.puts s}
    end


  private
    def colorize(elements, map)
      results, decorators, indent = [], [], ""
      elements.each do |element|
        case element
        when Symbol
          raise "Unknown output type: #{element}" unless map.has_key?(element)
          decorators = Array(map[element])
        when Fixnum
          indent = " " * element
        when nil, ''
          results << ''
        else
          results << decorators.inject(Rainbow "#{indent}#{element}") {|presenter, decorator| presenter.send decorator}
        end
      end
      results
    end
  end

  extend Output
end
