require_relative "../../lib/gergich/capture"

RSpec.describe Gergich::Capture do
  let!(:draft) { double }

  before do
    allow(Gergich::Draft).to receive(:new).and_return(draft)
  end

  context "rubocop" do
    it "should catch errors" do
      allow(described_class).to receive(:run_command).and_return([0, <<-OUTPUT])
bin/gergich:47:8: C: Prefer double-quoted strings
if ENV['DEBUG']
       ^^^^^^^
OUTPUT
      expect(draft).to receive(:add_comment).with(
        "bin/gergich",
        47,
        "[rubocop] C: Prefer double-quoted strings\n\n if ENV['DEBUG']\n        ^^^^^^^\n",
        "error"
      )
      described_class.run("rubocop", "false")
    end
  end

  context "eslint" do
    it "should catch errors" do
      allow(described_class).to receive(:run_command).and_return([0, <<-OUTPUT])
jsapp/models/user.js
  4:21  error  Missing semicolon  semi
OUTPUT
      expect(draft).to receive(:add_comment).with(
        "jsapp/models/user.js",
        4,
        "[eslint] Missing semicolon",
        "error"
      )
      described_class.run("eslint", "false")
    end
  end

  context "i18nliner" do
    it "should catch errors" do
      allow(described_class).to receive(:run_command).and_return([0, <<-OUTPUT])
1)
invalid signature on line 4: <unsupported expression>
jsapp/models/user.js
OUTPUT
      expect(draft).to receive(:add_comment).with(
        "jsapp/models/user.js",
        4,
        "[i18n] invalid signature: <unsupported expression>",
        "error"
      )
      described_class.run("i18nliner", "false")
    end
  end
end
