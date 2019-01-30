# frozen_string_literal: true

require_relative "../../support/capture_shared_examples"

RSpec.describe Gergich::Capture::BrakemanCapture do
  let(:output) do
    File.read(
      File.expand_path(File.dirname(__FILE__) + "/brakeman_example.json")
    )
  end

  let(:comments) do
    [
      {
        path: "app/models/custom_data.rb",
        position: 36,
        message: <<~MESSAGE.strip,
          [brakeman] Attribute Restriction: attr_accessible is recommended over attr_protected
            See: http://brakemanscanner.org/docs/warning_types/attribute_restriction/
        MESSAGE
        severity: "warn"
      },
      {
        path: "app/models/submission_comment.rb",
        position: 0,
        message: <<~MESSAGE.strip,
          [brakeman] Mass Assignment: Potentially dangerous attribute available for mass assignment
            Code: :context_id
            See: http://brakemanscanner.org/docs/warning_types/mass_assignment/
        MESSAGE
        severity: "warn"
      },
      {
        path: "app/controllers/context_controller.rb",
        position: 60,
        message: <<~MESSAGE.strip,
          [brakeman] Redirect: Possible unprotected redirect
            Code: redirect_to(CanvasKaltura::ClientV3.new.assetSwfUrl(params[:id]))
            User Input: params[:id]
            See: http://brakemanscanner.org/docs/warning_types/redirect/
        MESSAGE
        severity: "warn"
      },
      {
        path: "app/views/context/object_snippet.html.erb",
        position: 6,
        message: <<~MESSAGE.strip,
          [brakeman] Cross Site Scripting: Unescaped parameter value
            Code: Base64.decode64((params[:object_data] or ""))
            User Input: params[:object_data]
            See: http://brakemanscanner.org/docs/warning_types/cross_site_scripting
        MESSAGE
        severity: "warn"
      },
      {
        path: "app/models/account.rb",
        position: 795,
        message: <<~MESSAGE.strip,
          [brakeman] SQL Injection: Possible SQL injection
            Code: Account.find_by_sql(Account.sub_account_ids_recursive_sql(parent_account_id))
            User Input: Account.sub_account_ids_recursive_sql(parent_account_id)
            See: http://brakemanscanner.org/docs/warning_types/sql_injection/
        MESSAGE
        severity: "error"
      },
      {
        path: "lib/cc/importer/blti_converter.rb",
        position: 145,
        message: <<~MESSAGE.strip,
          [brakeman] SSL Verification Bypass: SSL certificate verification was bypassed
            Code: Net::HTTP.new(URI.parse(url).host, URI.parse(url).port).verify_mode = OpenSSL::SSL::VERIFY_NONE
            See: http://brakemanscanner.org/docs/warning_types/ssl_verification_bypass/
        MESSAGE
        severity: "error"
      },
      {
        path: "lib/cc/importer/canvas/quiz_converter.rb",
        position: 44,
        message: <<~MESSAGE.strip,
          [brakeman] Command Injection: Possible command injection
            Code: `\#{Qti.get_conversion_command(File.join(qti_folder, "qti_2_1"), qti_folder)}`
            User Input: Qti.get_conversion_command(File.join(qti_folder, "qti_2_1"), qti_folder)
            See: http://brakemanscanner.org/docs/warning_types/command_injection/
        MESSAGE
        severity: "warn"
      }
    ]
  end

  it_behaves_like "a captor"
end
