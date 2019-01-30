# frozen_string_literal: true

require_relative "../../support/capture_shared_examples"

RSpec.describe Gergich::Capture::StylelintCapture do
  let(:output) do
    <<~OUTPUT
      app/stylesheets/base/_print.scss
       3:17  ✖  Unexpected invalid hex color "#owiehfi"   color-no-invalid-hex
       3:17  ⚠  Expected "#owiehfi" to be "#OWIEHFI"      color-hex-case

      app/stylesheets/base/_variables.scss
        2:15  ✖  Unexpected invalid hex color "#2D3B4"   color-no-invalid-hex
       30:15  ⚠  Expected "#2d3b4a" to be "#2D3B4A"      color-hex-case
    OUTPUT
  end
  let(:comments) do
    [
      {
        path: "app/stylesheets/base/_print.scss",
        position: 3,
        message: "[stylelint] Unexpected invalid hex color \"#owiehfi\"",
        severity: "error"
      },
      {
        path: "app/stylesheets/base/_print.scss",
        position: 3,
        message: "[stylelint] Expected \"#owiehfi\" to be \"#OWIEHFI\"",
        severity: "warn"
      },
      {
        path: "app/stylesheets/base/_variables.scss",
        position: 2,
        message: "[stylelint] Unexpected invalid hex color \"#2D3B4\"",
        severity: "error"
      },
      {
        path: "app/stylesheets/base/_variables.scss",
        position: 30,
        message: "[stylelint] Expected \"#2d3b4a\" to be \"#2D3B4A\"",
        severity: "warn"
      }
    ]
  end

  it_behaves_like "a captor"
end
