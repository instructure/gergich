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
       45:12  ℹ  Expected "#2d3b4a" to be "#2D3B4A"      color-hex-case
    OUTPUT
  end
  let(:comments) do
    [
      {
        path: "app/stylesheets/base/_print.scss",
        position: 3,
        message: "Unexpected invalid hex color \"#owiehfi\"",
        severity: "error",
        source: "stylelint"
      },
      {
        path: "app/stylesheets/base/_print.scss",
        position: 3,
        message: "Expected \"#owiehfi\" to be \"#OWIEHFI\"",
        severity: "warn",
        source: "stylelint"
      },
      {
        path: "app/stylesheets/base/_variables.scss",
        position: 2,
        message: "Unexpected invalid hex color \"#2D3B4\"",
        severity: "error",
        source: "stylelint"
      },
      {
        path: "app/stylesheets/base/_variables.scss",
        position: 30,
        message: "Expected \"#2d3b4a\" to be \"#2D3B4A\"",
        severity: "warn",
        source: "stylelint"
      },
      {
        path: "app/stylesheets/base/_variables.scss",
        position: 45,
        message: "Expected \"#2d3b4a\" to be \"#2D3B4A\"",
        severity: "info",
        source: "stylelint"
      }
    ]
  end

  it_behaves_like "a captor"
end
