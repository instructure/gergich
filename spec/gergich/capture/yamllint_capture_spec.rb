# frozen_string_literal: true

require_relative "../../support/capture_shared_examples"

RSpec.describe Gergich::Capture::YamllintCapture do
  let(:output) do
    <<~OUTPUT
      ./api/config/lti/development/config.yml
        2:8       error    string value is redundantly quoted with double quotes  (quoted-strings)
        12:3      warning  comment not indented like content  (comments-indentation)
    OUTPUT
  end
  let(:comments) do
    [
      {
        path: "api/config/lti/development/config.yml",
        position: 2,
        message: "[yamllint] string value is redundantly quoted with double quotes",
        severity: "error"
      },
      {
        path: "api/config/lti/development/config.yml",
        position: 12,
        message: "[yamllint] comment not indented like content",
        severity: "warn"
      }
    ]
  end

  it_behaves_like "a captor"
end
