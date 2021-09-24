# frozen_string_literal: true

require_relative "../../support/capture_shared_examples"

RSpec.describe Gergich::Capture::I18nlinerCapture do
  let(:output) do
    <<~OUTPUT
      1)
      invalid signature on line 4: <unsupported expression>
      jsapp/models/user.js
    OUTPUT
  end
  let(:comments) do
    [
      {
        path: "jsapp/models/user.js",
        position: 4,
        message: "invalid signature: <unsupported expression>",
        severity: "error",
        source: "i18n"
      }
    ]
  end

  it_behaves_like "a captor"
end
