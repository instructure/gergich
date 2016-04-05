module Gergich
  module Capture
    class EslintCapture < BaseCapture
      def run(output)
        # e.g. "  4:21  error  Missing semicolon  semi"
        error_pattern = /\s\s+(\d+):\d+\s+\w+\s+(.*?)\s+[\w-]+\n/
        pattern = %r{            # Example:
          ^([^\n]+)\n            #   jsapp/models/user.js
          ((#{error_pattern})+)  #     4:21  error  Missing semicolon  semi
        }mx

        output.scan(pattern).map { |file, errors|
          errors.scan(error_pattern).map { |line, error|
            { path: file, message: "[eslint] #{error}", position: line.to_i, severity: "error" }
          }
        }.compact.flatten
      end
    end
  end
end
