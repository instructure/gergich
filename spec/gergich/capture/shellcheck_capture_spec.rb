require_relative "../../support/capture_shared_examples"

RSpec.describe Gergich::Capture::ShellcheckCapture do
  let(:output) do
    <<-'OUTPUT'
[
  {
    "file": "bin/sync-translations.sh",
    "line": 23,
    "endLine": 23,
    "column": 21,
    "endColumn": 21,
    "level": "style",
    "code": 2006,
    "message": "Use $(..) instead of legacy `..`."
  },
  {
    "file": "bin/sync-translations.sh",
    "line": 23,
    "endLine": 23,
    "column": 43,
    "endColumn": 43,
    "level": "warning",
    "code": 2046,
    "message": "Quote this to prevent word splitting."
  },
  {
    "file": "bin/sync-translations.sh",
    "line": 32,
    "endLine": 32,
    "column": 62,
    "endColumn": 62,
    "level": "info",
    "code": 2086,
    "message": "Double quote to prevent globbing and word splitting."
  },
  {
    "file": "fail.sh",
    "line": 3,
    "endLine": 3,
    "column": 12,
    "endColumn": 12,
    "level": "error",
    "code": 1101,
    "message": "Delete trailing spaces after \\ to break line (or use quotes for literal space)."
  }
]
    OUTPUT
  end

  let(:comments) do
    [
      {
        path: "bin/sync-translations.sh",
        position: 23,
        message: "Use $(..) instead of legacy `..`.",
        severity: "info"
      },
      {
        path: "bin/sync-translations.sh",
        position: 23,
        message: "Quote this to prevent word splitting.",
        severity: "warn"
      },
      {
        path: "bin/sync-translations.sh",
        position: 32,
        message: "Double quote to prevent globbing and word splitting.",
        severity: "info"
      },
      {
        path: "fail.sh",
        position: 3,
        message: "Delete trailing spaces after \\ to break line (or use quotes for literal space).",
        severity: "error"
      }
    ]
  end

  it_behaves_like "a captor"
end
