# frozen_string_literal: true

SimpleCov.start do
  add_filter "/spec/"
end

SimpleCov.at_exit { SimpleCov.result }
