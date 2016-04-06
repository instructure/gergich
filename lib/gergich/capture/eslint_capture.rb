module Gergich
  module Capture
    class EslintCapture < BaseCapture
      SEVERITY_MAP = { "error" => "error", "warning" => "warn" }.freeze

      def run(output)
        # e.g. "  4:21  error  Missing semicolon  semi"
        error_pattern = /\s\s+(\d+):\d+\s+(\w+)\s+(.*?)\s+[\w-]+\n/
        pattern = %r{            # Example:
          ^([^\n]+)\n            #   jsapp/models/user.js
          ((#{error_pattern})+)  #     4:21  error  Missing semicolon  semi
        }mx

        output.scan(pattern).map { |file, errors|
          errors.scan(error_pattern).map { |line, severity, error|
            severity = SEVERITY_MAP[severity]
            { path: file, message: "[eslint] #{error}", position: line.to_i, severity: severity }
          }
        }.compact.flatten
      end
    end
  end
end
