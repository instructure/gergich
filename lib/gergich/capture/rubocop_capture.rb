module Gergich
  module Capture
    class RubocopCapture < BaseCapture
      def run(output)
        pattern = %r{                     # Example:
          ^([^:\n]+):(\d+):\d+:\s(.*?)\n  #   bin/gergich:47:8: C: Prefer double-quoted strings
          ([^\n]+\n                       #   if ENV['DEBUG']
           [^^\n]*\^+[^^\n]*\n)?          #          ^^^^^^^
        }mx

        output.scan(pattern).map { |file, line, error, context|
          context = "\n\n" + context.gsub(/^/, " ") if context
          { path: file, message: "[rubocop] #{error}#{context}",
            position: line.to_i, severity: "error" }
        }.compact
      end
    end
  end
end
