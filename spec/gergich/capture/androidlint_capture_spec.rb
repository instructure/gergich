require_relative "../../support/capture_shared_examples"

RSpec.describe Gergich::Capture::AndroidlintCapture do
  # rubocop:disable Metrics/LineLength
  let(:rtl_hardcoded) { 'Consider adding android:drawableStart="@drawable/a_media" to better support right-to-left layouts [RtlHardcoded]' }
  let(:rtl_enabled) { "The project references RTL attributes, but does not explicitly enable or disable RTL support with android:supportsRtl in the manifest [RtlEnabled]" }
  let(:lint_error) { 'No .class files were found in project "0.0.2", so none of the classfile based checks could be run. Does the project need to be built first? [LintError]' }
  let(:unused_quantity) { 'For language "fr" (French) the following quantities are not relevant: few, zero [UnusedQuantity]' }
  let(:output) do
    <<-OUTPUT
/path/to/some.xml:27: Warning: #{rtl_hardcoded}
    android:drawableLeft="@drawable/ic_cv_media"/>
    ~~~~~~~~~~~~~~~~~~~~

/path/to/AndroidManifest.xml: Warning: #{rtl_enabled}

/path/to/library/0.0.2: Error: #{lint_error}

/path/to/values.xml:5: Warning: #{unused_quantity}
    <plurals name="number">
    ^

    OUTPUT
  end

  let(:comments) do
    [
      {
        path: "/path/to/some.xml",
        position: 27,
        message: "[androidlint] #{rtl_hardcoded}\n\n    android:drawableLeft=\"@drawable/ic_cv_media\"/>\n    ~~~~~~~~~~~~~~~~~~~~",
        severity: "warn"
      },
      {
        path: "/path/to/AndroidManifest.xml",
        position: 0,
        message: "[androidlint] #{rtl_enabled}",
        severity: "warn"
      },
      {
        path: "/path/to/library/0.0.2",
        position: 0,
        message: "[androidlint] #{lint_error}",
        severity: "error"
      },
      {
        path: "/path/to/values.xml",
        position: 5,
        message: "[androidlint] #{unused_quantity}\n\n    <plurals name=\"number\">\n    ^",
        severity: "warn"
      }
    ]
  end

  it_behaves_like "a captor"
end
