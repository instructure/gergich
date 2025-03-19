# frozen_string_literal: true

module Gergich
  module Capture
    class TscCapture < BaseCapture
      def run(output)
        pattern = /([^(\n]+)\((\d+),(\d+)\): (\w+) (\w+): (.*(\n  .*)*)/

        output.scan(pattern).map do |file, line, pos, severity, code, error|
          {
            path: file,
            message: error,
            source: "tsc",
            rule: code,
            position: {
              start_line: line.to_i,
              start_character: pos.to_i,
              end_line: line.to_i,
              end_character: pos.to_i
            },
            severity: severity
          }
        end
      end
    end
  end
end
