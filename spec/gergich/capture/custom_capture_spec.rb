# frozen_string_literal: true

require_relative "../../../lib/gergich/capture"

RSpec.describe "CustomCaptor" do
  let(:described_class) do
    Class.new do
      def run(output)
        output.scan(/^(.+?):(\d+): (.*)$/).map do |file, line, error|
          { path: file, message: error, position: line.to_i, severity: "error" }
        end
      end
    end
  end
  let(:capture_format) { "custom:sqlite3:CustomCaptor" }
  let(:output) do
    <<~TEXT
      foo.rb:1: you done screwed up
    TEXT
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

  before do
    allow(Gergich::Capture).to receive(:const_get).with("CustomCaptor").and_return(described_class)
  end

  it "loads" do
    captor = Gergich::Capture.load_captor(capture_format)
    expect(captor).to eq(described_class)
  end

  it "catches errors" do
    comments = described_class.new.run(output)
    expect(comments).to match_array(comments)
  end
end
