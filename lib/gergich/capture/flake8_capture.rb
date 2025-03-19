# frozen_string_literal: true

module Gergich
  module Capture
    class Flake8Capture < BaseCapture
      def run(output)
        # Example:
        # ./djangogeneric/settings/base.py:73:80: E501 line too long (81 > 79 characters)
        pattern = /
          ^([^:\n]+):(\d+):\d+:\s(.*?)\n
        /mx

        output.scan(pattern).filter_map do |file, line, error|
          { path: file,
            message: error,
            source: "flake8",
            position: line.to_i,
            severity: "error" }
        end
      end
    end
  end
end
