# frozen_string_literal: true

module Gergich
  module Capture
    class YamllintCapture < BaseCapture
      SEVERITY_MAP = { "error" => "error", "warning" => "warn" }.freeze

      def run(output)
        # e.g. "  9:5       error    string value redundantly  (quoted-strings)"
        error_pattern = %r{\s\s+(\d+):\d+\s+(\w+)\s+(.*?)\s+\([\w/-]+\)\n}
        pattern = %r{            # Example:
          ^./([^\n]+)\n         #   ./api/config/lti/development/config.yml
          ((#{error_pattern})+)  #     9:5       error    string value redundantly  (quoted-strings)
        }mx

        output.scan(pattern).filter_map do |file, errors|
          errors.scan(error_pattern).map do |line, severity, error|
            severity = SEVERITY_MAP[severity]
            {
              path: file,
              message: error,
              source: "yamllint",
              position: line.to_i,
              severity: severity
            }
          end
        end.flatten
      end
    end
  end
end
