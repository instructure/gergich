require_relative "../../lib/gergich/capture"

RSpec.describe Gergich::Capture do
  let!(:draft) { double }

  before do
    allow(Gergich::Draft).to receive(:new).and_return(draft)
  end

  context "stdin" do
    let :output do
      <<-OUTPUT
jsapp/models/user.js
  4:21  error  Missing semicolon  semi
OUTPUT
    end

    before do
      $stdin = StringIO.new(output)
    end

    after do
      $stdin = STDIN
    end

    it "should catch errors" do
      expect(draft).to receive(:add_comment).with(
        "jsapp/models/user.js",
        4,
        "[eslint] Missing semicolon",
        "error"
      )
      described_class.run("eslint", "-")
    end

    it "shouldn't eat stdin" do
      allow(draft).to receive(:add_comment)
      expect($stdout).to receive(:puts).exactly(output.lines.size).times
      described_class.run("eslint", "-")
    end
  end
end
