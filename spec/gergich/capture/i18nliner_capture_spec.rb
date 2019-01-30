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
        message: "[i18n] invalid signature: <unsupported expression>",
        severity: "error"
      }
    ]
  end

  it_behaves_like "a captor"
end
