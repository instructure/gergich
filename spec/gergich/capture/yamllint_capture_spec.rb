# frozen_string_literal: true

require_relative "../../support/capture_shared_examples"

RSpec.describe Gergich::Capture::YamllintCapture do
  let(:output) do
    <<~TEXT
      ./api/config/lti/development/config.yml
        2:8       error    string value is redundantly quoted with double quotes  (quoted-strings)
        12:3      warning  comment not indented like content  (comments-indentation)
    TEXT
  end
  let(:comments) do
    [
      {
        path: "api/config/lti/development/config.yml",
        position: 2,
        message: "string value is redundantly quoted with double quotes",
        severity: "error",
        source: "yamllint"
      },
      {
        path: "api/config/lti/development/config.yml",
        position: 12,
        message: "comment not indented like content",
        severity: "warn",
        source: "yamllint"
      }
    ]
  end

  it_behaves_like "a captor"
end
