# frozen_string_literal: true

require_relative "../../support/capture_shared_examples"

RSpec.describe Gergich::Capture::Flake8Capture do
  let(:output) do
    <<~TEXT
      ./djangogeneric/settings/base.py:73:80: E501 line too long (81 > 79 characters)
    TEXT
  end
  let(:comments) do
    [
      {
        path: "./djangogeneric/settings/base.py",
        position: 73,
        message: "E501 line too long (81 > 79 characters)",
        severity: "error",
        source: "flake8"
      }
    ]
  end

  it_behaves_like "a captor"
end
