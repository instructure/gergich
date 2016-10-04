require_relative "../../support/capture_shared_examples"

RSpec.describe Gergich::Capture::Flake8Capture do
  let(:output) do
    <<-OUTPUT
./djangogeneric/settings/base.py:73:80: E501 line too long (81 > 79 characters)
    OUTPUT
  end
  let(:comments) do
    [
      {
        path: "./djangogeneric/settings/base.py",
        position: 73,
        message: "[flake8] E501 line too long (81 > 79 characters)",
        severity: "error"
      }
    ]
  end

  it_behaves_like "a captor"
end
