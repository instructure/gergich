# frozen_string_literal: true

require_relative "../../support/capture_shared_examples"

RSpec.describe Gergich::Capture::TscCapture do
  let(:output) do
    <<~TEXT
      bad.ts(2,3): error TS2345: Argument of type 'number' is not assignable to parameter of type 'string'.
      bad.ts(4,10): error TS2345: Argument of type 'string' is not assignable to parameter of type 'number'.
        Some extra info on this error
    TEXT
  end
  let(:comments) do
    [
      {
        path: "bad.ts",
        position: {
          start_line: 2,
          start_character: 3,
          end_line: 2,
          end_character: 3
        },
        message: "Argument of type 'number' is not assignable to parameter of type 'string'.",
        severity: "error",
        source: "tsc",
        rule: "TS2345"
      },
      {
        path: "bad.ts",
        position: {
          start_line: 4,
          start_character: 10,
          end_line: 4,
          end_character: 10
        },
        message: "Argument of type 'string' is not assignable to parameter of type 'number'.\n  " \
                 "Some extra info on this error",
        severity: "error",
        source: "tsc",
        rule: "TS2345"
      }
    ]
  end

  it_behaves_like "a captor"
end
