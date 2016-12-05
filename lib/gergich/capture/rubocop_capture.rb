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
        pattern = /
          ^([^:\n]+):(\d+):\d+:\s(\w):\s(.*?)\n
          ([^\n]+\n
           [^^\n]*\^+[^^\n]*\n)?
        /mx

        output.scan(pattern).map { |file, line, severity, error, context|
          context = "\n\n" + context.gsub(/^/, " ") if context
          {
            path: file,
            position: line.to_i,
            message: "[rubocop] #{error}#{context}",
            severity: SEVERITY_MAP[severity]
          }
        }.compact
      end
    end
  end
end
