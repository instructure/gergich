# frozen_string_literal: true

module Gergich
  module Capture
    class RubocopCapture < BaseCapture
      SEVERITY_MAP = {
        "R" => "info",  # refactor
        "C" => "info",  # convention
        "W" => "warn",  # warning
        "E" => "error", # error
        "F" => "error"  # fatal
      }.freeze

      def run(output)
        # Example:
        #   bin/gergich:47:8: C: Prefer double-quoted strings
        #   if ENV['DEBUG']
        #          ^^^^^^^
        #
        # 1 file inspected, 35 offenses detected, 27 offenses auto-correctable
        #
        # Example:
        # 2 files inspected, 40 offenses detected, 31 offenses auto-correctable
        #
        # Example:
        # 1 file inspected, no offenses detected

        first_line_pattern = /^([^:\n]+):(\d+):\d+:\s(\w):\s/

        parts = output.split(first_line_pattern)

        unless parts.last.match?(/^\d+ files? inspect/)
          raise "RuboCop failed to run properly:\n\n#{output}"
        end

        # strip off the summary line from the last error
        parts[-1] = parts[-1].split("\n")[0..-2].join("\n")

        # strip off the header
        parts.shift

        messages = []

        until parts.empty?
          file = parts.shift
          line = parts.shift
          severity = parts.shift
          message = parts.shift
          # if there is code context at the end, separate it and indent it
          # so that gerrit preserves formatting
          if /(?<context>[^\n]+\n *\^+\n)/m =~ message
            message.sub!(context, "\n#{context.gsub(/^/, ' ')}")
          end
          match = message.match(
            %r{
              \A
              (?<corrected>\[Corrected\]\s)?
              (?<correctable>\[Correctable\]\s)?
              (?:(?<cop>[A-Za-z/]+):\s)?
              (?<message>.*)
              \z
              }mx
          )

          # rubocop:disable Style/DoubleNegation
          messages << {
            path: file,
            position: line.to_i,
            message: match[:message],
            rule: match[:cop],
            corrected: !!match[:corrected],
            correctable: !!match[:correctable],
            severity: SEVERITY_MAP[severity],
            source: "rubocop"
          }
          # rubocop:enable Style/DoubleNegation
        end

        messages
      end
    end
  end
end
