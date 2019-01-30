# frozen_string_literal: true

require_relative "../../../lib/gergich/capture"

RSpec.describe "CustomCaptor" do
  class CustomCaptor
    def run(output)
      output.scan(/^(.+?):(\d+): (.*)$/).map do |file, line, error|
        { path: file, message: error, position: line.to_i, severity: "error" }
      end
    end
  end

  let(:described_class) { CustomCaptor }
  let(:capture_format) { "custom:sqlite3:CustomCaptor" }
  let(:output) do
    <<~OUTPUT
      foo.rb:1: you done screwed up
    OUTPUT
  end
  let(:comments) do
    [
      {
        path: "foo.rb",
        position: 1,
        message: "you done screwed up",
        severity: "error"
      }
    ]
  end

  it "loads" do
    captor = Gergich::Capture.load_captor(capture_format)
    expect(captor).to eq(described_class)
  end

  it "catches errors" do
    comments = subject.run(output)
    expect(comments).to match_array(comments)
  end
end
