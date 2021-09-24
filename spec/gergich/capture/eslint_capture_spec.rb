# frozen_string_literal: true

require_relative "../../support/capture_shared_examples"

RSpec.describe Gergich::Capture::EslintCapture do
  let(:output) do
    <<~OUTPUT
      jsapp/models/user.js
        4:21  error    Missing semicolon  semi
        5:1   warning  Too much cowbell   cowbell-overload
    OUTPUT
  end
  let(:comments) do
    [
      {
        path: "jsapp/models/user.js",
        position: 4,
        message: "Missing semicolon",
        severity: "error",
        source: "eslint"
      },
      {
        path: "jsapp/models/user.js",
        position: 5,
        message: "Too much cowbell",
        severity: "warn",
        source: "eslint"
      }
    ]
  end

  it_behaves_like "a captor"
end
