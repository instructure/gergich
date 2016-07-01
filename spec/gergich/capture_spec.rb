require_relative "../../lib/gergich/capture"
require_relative "../../lib/gergich"

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
lib/gergich.rb:22:55: W: Line is too long. [55/54]
    def initialize(ref = "HEAD", revision_number = nil)
                                                     ^^
OUTPUT
      expect(draft).to receive(:add_comment).with(
        "bin/gergich",
        47,
        "[rubocop] Prefer double-quoted strings\n\n if ENV['DEBUG']\n        ^^^^^^^\n",
        "info"
      )
      expect(draft).to receive(:add_comment)
        .with("lib/gergich.rb", 22, <<-OUTPUT, "warn")
[rubocop] Line is too long. [55/54]

     def initialize(ref = "HEAD", revision_number = nil)
                                                      ^^
OUTPUT
      described_class.run("rubocop", "false")
    end
  end

  # rubocop:disable Metrics/LineLength
  context "swiftlint" do
    it "should catch errors" do
      colon_violation = "Colon Violation: Colons should be next to the identifier when specifying a type. (colon)"
      line_length_violation = "Line Length Violation: Line should be 100 characters or less: currently 129 characters (line_length)"
      force_cast_violation = "Force Cast Violation: Force casts should be avoided. (force_cast)"
      allow(described_class).to receive(:run_command).and_return([0, <<-OUTPUT])
/path/to/My.swift:13:22: warning: #{colon_violation}
/path/to/Fail.swift:76: warning: #{line_length_violation}
/path/to/Cast.swift:15:9: error: #{force_cast_violation}
      OUTPUT
      expect(draft).to receive(:add_comment).with(
        "/path/to/My.swift",
        13,
        "[swiftlint] #{colon_violation}",
        "warn"
      )
      expect(draft).to receive(:add_comment).with(
        "/path/to/Fail.swift",
        76,
        "[swiftlint] #{line_length_violation}",
        "warn"
      )
      expect(draft).to receive(:add_comment).with(
        "/path/to/Cast.swift",
        15,
        "[swiftlint] #{force_cast_violation}",
        "error"
      )
      described_class.run("swiftlint", "false")
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
