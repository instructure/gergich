# frozen_string_literal: true

require_relative "../../support/capture_shared_examples"

RSpec.describe Gergich::Capture::RubocopCapture do
  subject(:captor) { described_class.new }

  let(:output) do
    <<~TEXT
      Offenses:

      bin/gergich:47:8: C: Style/StringLiteral: Prefer double-quoted strings
      if ENV['DEBUG']
             ^^^^^^^
      foo/bar/baz.rb:1:2: W: no context for this one :shrug:
      lib/gergich.rb:10:9: E: this is a terrible name

      seriously, what were you thinking?
          def foo
              ^^^
      lib/gergich.rb:22:55: W: Layout/LineLength: Line is too long. [55/54]
          def initialize(ref = "HEAD", revision_number = nil)
                                                           ^^
      script/rlint:49:5: E: [Correctable] Layout/IndentationConsistency: Inconsistent indentation detected.
          require 'pp'
          ^^^^^^^^^^^^
      script/rlint:49:5: E: [Corrected] Layout/IndentationConsistency: Inconsistent indentation detected.
          require 'pp'
          ^^^^^^^^^^^^

      1 file inspected, 35 offenses detected, 27 offenses auto-correctable
    TEXT
  end
  let(:comments) do
    [
      {
        path: "bin/gergich",
        position: 47,
        message: "Prefer double-quoted strings\n\n if ENV['DEBUG']\n        ^^^^^^^\n",
        severity: "info",
        correctable: false,
        corrected: false,
        rule: "Style/StringLiteral",
        source: "rubocop"
      },
      {
        path: "foo/bar/baz.rb",
        position: 1,
        message: "no context for this one :shrug:\n",
        severity: "warn",
        correctable: false,
        corrected: false,
        rule: nil,
        source: "rubocop"
      },
      {
        path: "lib/gergich.rb",
        position: 10,
        message: <<~TEXT,
          this is a terrible name

          seriously, what were you thinking?

               def foo
                   ^^^
        TEXT
        severity: "error",
        correctable: false,
        corrected: false,
        rule: nil,
        source: "rubocop"
      },
      {
        path: "lib/gergich.rb",
        position: 22,
        message: <<~TEXT,
          Line is too long. [55/54]

               def initialize(ref = "HEAD", revision_number = nil)
                                                                ^^
        TEXT
        severity: "warn",
        correctable: false,
        corrected: false,
        rule: "Layout/LineLength",
        source: "rubocop"
      },
      {
        path: "script/rlint",
        position: 49,
        message: "Inconsistent indentation detected.\n\n     require 'pp'\n     ^^^^^^^^^^^^\n",
        rule: "Layout/IndentationConsistency",
        corrected: false,
        correctable: true,
        severity: "error",
        source: "rubocop"
      },
      {
        path: "script/rlint",
        position: 49,
        message: "Inconsistent indentation detected.\n\n     require 'pp'\n     ^^^^^^^^^^^^\n",
        rule: "Layout/IndentationConsistency",
        corrected: true,
        correctable: false,
        severity: "error",
        source: "rubocop"
      }
    ]
  end

  it_behaves_like "a captor"

  it "raises an error if it couldn't run" do
    expect { captor.run(<<-TEXT) }.to raise_error(/RuboCop failed to run properly/)
      Could not find i18n-1.8.9 in any of the sources
      Run `bundle install` to install missing gems.
    TEXT
  end
end
