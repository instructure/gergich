# frozen_string_literal: true

module Gergich
  module Capture
    class BrakemanCapture < BaseCapture
      # Map Brakeman "confidence level" to severity.
      # http://brakemanscanner.org/docs/confidence/
      SEVERITY_MAP = {
        "Weak" => "warn",
        "Medium" => "warn",
        "High" => "error"
      }.freeze

      def run(output)
        # See brakeman_example.json for sample output.
        JSON.parse(output)["warnings"].map { |warning|
          message = "#{warning['warning_type']}: #{warning['message']}"
          message += "\n  Code: #{warning['code']}" if warning["code"]
          message += "\n  User Input: #{warning['user_input']}" if warning["user_input"]
          message += "\n  See: #{warning['link']}" if warning["link"]
          {
            path: warning["file"],
            position: warning["line"] || 0,
            message: message,
            severity: SEVERITY_MAP[warning["confidence"]],
            source: "brakeman"
          }
        }.compact
      end
    end
  end
end
