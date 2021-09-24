# frozen_string_literal: true

require_relative "../../support/capture_shared_examples"

RSpec.describe Gergich::Capture::SwiftlintCapture do
  # rubocop:disable Layout/LineLength
  let(:colon_violation) { "Colon Violation: Colons should be next to the identifier when specifying a type. (colon)" }
  let(:line_length_violation) { "Line Length Violation: Line should be 100 characters or less: currently 129 characters (line_length)" }
  let(:force_cast_violation) { "Force Cast Violation: Force casts should be avoided. (force_cast)" }
  # rubocop:enable Layout/LineLength
  let(:output) do
    <<~OUTPUT
      /path/to/My.swift:13:22: warning: #{colon_violation}
      /path/to/Fail.swift:76: warning: #{line_length_violation}
      /path/to/Cast.swift:15:9: error: #{force_cast_violation}
    OUTPUT
  end
  let(:comments) do
    [
      {
        path: "/path/to/My.swift",
        position: 13,
        message: colon_violation,
        severity: "warn",
        source: "swiftlint"
      },
      {
        path: "/path/to/Fail.swift",
        position: 76,
        message: line_length_violation.to_s,
        severity: "warn",
        source: "swiftlint"
      },
      {
        path: "/path/to/Cast.swift",
        position: 15,
        message: force_cast_violation.to_s,
        severity: "error",
        source: "swiftlint"
      }
    ]
  end

  it_behaves_like "a captor"
end
