# frozen_string_literal: true

module Gergich
  module Capture
    class I18nlinerCapture < BaseCapture
      def run(output)
        pattern = %r{ # Example:
          ^\d+\)\n    #   1)
          (.*?)\n     #   invalid signature on line 4: <unsupported expression>
          (.*?)\n     #   jsapp/models/user.js
        }mx

        output.scan(pattern).map { |error, file|
          line = 1
          error.sub!(/ on line (\d+)/) do
            line = Regexp.last_match[1]
            ""
          end
          { path: file, message: error, source: "i18n", position: line.to_i, severity: "error" }
        }.compact
      end
    end
  end
end
