require_relative "../../support/capture_shared_examples"

RSpec.describe Gergich::Capture::RubocopCapture do
  let(:output) do
    <<-OUTPUT
bin/gergich:47:8: C: Prefer double-quoted strings
if ENV['DEBUG']
       ^^^^^^^
lib/gergich.rb:22:55: W: Line is too long. [55/54]
    def initialize(ref = "HEAD", revision_number = nil)
                                                     ^^
    OUTPUT
  end
  let(:comments) do
    [
      {
        path: "bin/gergich",
        position: 47,
        message: "[rubocop] Prefer double-quoted strings\n\n if ENV['DEBUG']\n        ^^^^^^^\n",
        severity: "info"
      },
      {
        path: "lib/gergich.rb",
        position: 22,
        message: <<-OUTPUT,
[rubocop] Line is too long. [55/54]

     def initialize(ref = "HEAD", revision_number = nil)
                                                      ^^
        OUTPUT
        severity: "warn"
      }
    ]
  end

  it_behaves_like "a captor"
end
