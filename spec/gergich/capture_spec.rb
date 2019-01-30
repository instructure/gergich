# frozen_string_literal: true

require_relative "../../lib/gergich/capture"

RSpec.describe Gergich::Capture do
  let!(:draft) { double }

  let :output do
    <<~OUTPUT
      #{path}
        4:21  error  Missing semicolon  semi
    OUTPUT
  end

  before do
    allow(Gergich::Draft).to receive(:new).and_return(draft)
    $stdin = StringIO.new(output)
  end

  after do
    $stdin = STDIN
  end

  context "stdin" do
    let(:path) { "jsapp/models/user.js" }

    it "should catch errors" do
      expect(draft).to receive(:add_comment).with(
        "jsapp/models/user.js",
        4,
        "[eslint] Missing semicolon",
        "error"
      )
      described_class.run("eslint", "-", suppress_output: true)
    end

    it "shouldn't eat stdin" do
      allow(draft).to receive(:add_comment)
      expect($stdout).to receive(:puts).exactly(output.lines.size).times
      described_class.run("eslint", "-")
    end
  end

  context "absolute paths" do
    before do
      allow(described_class).to receive(:base_path).and_return("/the/directory/")
    end

    context "under us" do
      let(:path) { "/the/directory/jsapp/models/user.js" }
      it "should be relativized" do
        expect(draft).to receive(:add_comment).with(
          "jsapp/models/user.js",
          4,
          "[eslint] Missing semicolon",
          "error"
        )
        described_class.run("eslint", "-", suppress_output: true)
      end
    end

    context "elsewhere" do
      let(:path) { "/other/directory/jsapp/models/user.js" }
      it "should not be relativized" do
        expect(draft).to receive(:add_comment).with(
          "/other/directory/jsapp/models/user.js",
          4,
          "[eslint] Missing semicolon",
          "error"
        )
        described_class.run("eslint", "-", suppress_output: true)
      end
    end
  end
end
