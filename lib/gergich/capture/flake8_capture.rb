module Gergich
  module Capture
    class Flake8Capture < BaseCapture
      def run(output)
        # Example:
        # ./djangogeneric/settings/base.py:73:80: E501 line too long (81 > 79 characters)
        pattern = /
          ^([^:\n]+):(\d+):\d+:\s(.*?)\n
        /mx

        output.scan(pattern).map { |file, line, error|
          { path: file, message: "[flake8] #{error}",
            position: line.to_i, severity: "error"}
        }.compact

      end
    end
  end
end
