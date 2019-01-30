# frozen_string_literal: true

require "json"

module Gergich
  module Capture
    class ShellcheckCapture < BaseCapture
      # https://github.com/koalaman/shellcheck/blob/6c068e7d/ShellCheck/Formatter/Format.hs#L41-L47
      SEVERITY_MAP = {
        "style" => "info",
        "info" => "info",
        "warning" => "warn",
        "error" => "error"
      }.freeze

      def run(output)
        JSON.parse(output).map do |warning|
          severity = warning.fetch("level")
          {
            path: warning.fetch("file"),
            position: warning.fetch("line"),
            message: warning.fetch("message"),
            severity: SEVERITY_MAP.fetch(severity)
          }
        end
      end
    end
  end
end
