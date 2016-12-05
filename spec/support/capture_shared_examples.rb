require_relative "../../lib/gergich/capture"

RSpec.shared_examples_for "a captor" do
  let(:capture_format) do
    Gergich::Capture::BaseCapture.normalize_captor_class_name(described_class)
  end

  it "loads" do
    captor = Gergich::Capture.load_captor(capture_format)
    expect(captor).to eq(described_class)
  end

  it "catches errors" do
    parsed_comments = subject.run(output)
    expect(parsed_comments).to match_array(comments)
  end
end
