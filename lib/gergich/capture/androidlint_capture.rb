module Gergich
  module Capture
    class AndroidlintCapture < BaseCapture
      # See http://tools.android.com/tips/lint-checks
      SEVERITY_MAP = {
        "Warning" => "warn",
        "Error" => "error",
        "Fatal" => "error"
      }.freeze

      def run(output)
        # rubocop:disable Metrics/LineLength
        #
        # Example:
        # /path/to/some.xml:27: Warning: Consider adding android:drawableStart="@drawable/a_media" to better support right-to-left layouts [RtlHardcoded]
        #     android:drawableLeft="@drawable/ic_cv_media"/>
        #     ~~~~~~~~~~~~~~~~~~~~
        #
        # /path/to/AndroidManifest.xml: Warning: The project references RTL attributes, but does not explicitly enable or disable RTL support with android:supportsRtl in the manifest [RtlEnabled]
        #
        # /path/to/library/0.0.2: Error: No .class files were found in project "0.0.2", so none of the classfile based checks could be run. Does the project need to be built first? [LintError]
        #
        # /path/to/values.xml:5: Warning: For language "fr" (French) the following quantities are not relevant: few, zero [UnusedQuantity]
        #    <plurals name="number">
        #    ^
        pattern = /
          ^([^:\n]+):(\d+)?:?\s(\w+):\s(.*?)\n
          ([^\n]+\n
           [\s~\^]+\n)?
        /mx

        output.scan(pattern).map { |file, line, severity, error, context|
          context = "\n\n" + context if context
          { path: file, message: "[androidlint] #{error}#{context}".strip,
            position: (line || 0).to_i, severity: SEVERITY_MAP[severity] }
        }.compact
      end
    end
  end
end
