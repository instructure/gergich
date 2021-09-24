# frozen_string_literal: true

module Gergich
  module Capture
    class StylelintCapture < BaseCapture
      # stylelint is a css linter
      # https://github.com/stylelint/stylelint
      #
      # example full output:
      # app/stylesheets/base/_print.scss
      #  3:17  ✖  Unexpected invalid hex color "#owiehfi"   color-no-invalid-hex
      #  3:17  ⚠  Expected "#owiehfi" to be "#OWIEHFI"      color-hex-case
      #
      # app/stylesheets/base/_variables.scss
      #   2:15  ✖  Unexpected invalid hex color "#2D3B4"   color-no-invalid-hex
      #  30:15  ⚠  Expected "#2d3b4a" to be "#2D3B4A"      color-hex-case

      MESSAGE_PREFIX = "[stylelint]"

      SEVERITY_MAP = {
        "✖" => "error",
        "⚠" => "warn",
        "ℹ" => "info"
      }.freeze

      # example file line:
      # app/stylesheets/base/_variables.scss
      FILE_PATH_PATTERN = /([^\n]+)\n/.freeze

      # example error line:
      #   1:15  ✖  Unexpected invalid hex color "#2D3B4"   color-no-invalid-hex
      ERROR_PATTERN = /^\s+(\d+):\d+\s+(✖|⚠|ℹ)\s+(.*?)\s\s+[^\n]+\n/.freeze

      PATTERN = /#{FILE_PATH_PATTERN}((#{ERROR_PATTERN})+)/.freeze

      def run(output)
        output.scan(PATTERN).map { |file, errors|
          errors.scan(ERROR_PATTERN).map { |line, severity, error|
            severity = SEVERITY_MAP[severity]
            {
              path: file,
              message: "#{MESSAGE_PREFIX} #{error}",
              position: line.to_i,
              severity: severity
            }
          }
        }.flatten.compact
      end
    end
  end
end
