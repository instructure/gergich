# frozen_string_literal: true

module Gergich
  module Capture
    class SwiftlintCapture < BaseCapture
      # See SeverityLevelsConfiguration.swift
      SEVERITY_MAP = {
        "error" => "error",  # console description
        "warning" => "warn",
        "w" => "warn",       # short console description
        "w/e" => "error"
      }.freeze

      def run(output)
        # rubocop:disable Layout/LineLength
        #
        # Example:
        # /path/to/My.swift:13:22: warning: Colon Violation: Colons should be next to the identifier when specifying a type. (colon)
        # /path/to/Fail.swift:80: warning: Line Length Violation: Line should be 100 characters or less: currently 108 characters (line_length)
        #
        # rubocop:enable Layout/LineLength
        pattern = /
          ^([^:\n]+):(\d+)(?::\d+)?:\s(\w+):\s(.*?)\n
        /mx

        output.scan(pattern).map { |file, line, severity, error, _context|
          { path: file, message: "[swiftlint] #{error}",
            position: line.to_i, severity: SEVERITY_MAP[severity] }
        }.compact
      end
    end
  end
end
