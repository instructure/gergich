require_relative "../../lib/gergich/capture"

RSpec.describe Gergich::Capture do
  let!(:draft) { double }

  before do
    allow(Gergich::Draft).to receive(:new).and_return(draft)
    $stdout = StringIO.new
  end

  after do
    $stdout = STDOUT
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
  4:21  error    Missing semicolon  semi
  5:1   warning  Too much cowbell   cowbell-overload
OUTPUT
      expect(draft).to receive(:add_comment).with(
        "jsapp/models/user.js",
        4,
        "[eslint] Missing semicolon",
        "error"
      )

      expect(draft).to receive(:add_comment).with(
        "jsapp/models/user.js",
        5,
        "[eslint] Too much cowbell",
        "warn"
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

  context "custom" do
    class CustomCaptor
      def run(output)
        puts output
        output.scan(/^(.+?):(\d+): (.*)$/).map do |file, line, error|
          { path: file, message: error, position: line.to_i, severity: "error" }
        end
      end
    end

    it "should catch errors" do
      allow(described_class).to receive(:run_command).and_return([0, <<-OUTPUT])
foo.rb:1: you done screwed up
OUTPUT
      expect(draft).to receive(:add_comment).with(
        "foo.rb",
        1,
        "you done screwed up",
        "error"
      )
      described_class.run("custom:sqlite3:CustomCaptor", "false")
    end
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
