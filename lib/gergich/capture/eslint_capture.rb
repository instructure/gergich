# frozen_string_literal: true

module Gergich
  module Capture
    class EslintCapture < BaseCapture
      SEVERITY_MAP = { "error" => "error", "warning" => "warn" }.freeze

      def run(output)
        # e.g. "  4:21  error  Missing semicolon  semi"
        error_pattern = %r{\s\s+(\d+):\d+\s+(\w+)\s+(.*?)\s+[\w/-]+\n}
        pattern = %r{            # Example:
          ^([^\n]+)\n            #   jsapp/models/user.js
          ((#{error_pattern})+)  #     4:21  error  Missing semicolon  semi
        }mx

        output.scan(pattern).filter_map do |file, errors|
          errors.scan(error_pattern).map do |line, severity, error|
            severity = SEVERITY_MAP[severity]
            { path: file,
              message: error,
              source: "eslint",
              position: line.to_i,
              severity: severity }
          end
        end.flatten
      end
    end
  end
end
