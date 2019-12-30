# frozen_string_literal: true

require_relative "../gergich"
require "English"

module Gergich
  module Capture
    class BaseCapture
      def self.inherited(subclass)
        name = normalize_captor_class_name(subclass)
        Capture.captors[name] = subclass
      end

      def self.normalize_captor_class_name(subclass)
        name = subclass.name.dup
        # borrowed from AS underscore, since we may not have it
        name.gsub!(/.*::|Capture\z/, "")
        name.gsub!(/([A-Z\d]+)([A-Z][a-z])/, "\\1_\\2")
        name.gsub!(/([a-z\d])([A-Z])/, "\\1_\\2")
        name.tr!("-", "_")
        name.downcase!
      end
    end

    class << self
      def run(format, command, add_comments: true, suppress_output: false)
        captor = load_captor(format)

        exit_code, output = run_command(command, suppress_output: suppress_output)
        comments = captor.new.run(output.gsub(/\e\[\d+m/m, ""))
        comments.each do |comment|
          comment[:path] = relativize(comment[:path])
        end

        draft = Gergich::Draft.new
        skip_paths = (ENV["SKIP_PATHS"] || "").split(",")
        if add_comments
          comments.each do |comment|
            next if skip_paths.any? { |path| comment[:path].start_with?(path) }

            draft.add_comment comment[:path], comment[:position],
                              comment[:message], comment[:severity]
          end
        end

        [exit_code, comments]
      end

      def base_path
        @base_path ||= File.expand_path(GERGICH_GIT_PATH) + "/"
      end

      def relativize(path)
        path.sub(base_path, "")
      end

      def run_command(command, suppress_output: false)
        exit_code = 0

        if command == "-"
          output = wiretap($stdin, suppress_output)
        else
          IO.popen("#{command} 2>&1", "r+") do |io|
            output = wiretap(io, suppress_output)
          end
          exit_code = $CHILD_STATUS.exitstatus
        end

        [exit_code, output]
      end

      def wiretap(io, suppress_output)
        output = []
        io.each do |line|
          $stdout.puts line unless suppress_output
          output << line
        end
        output.join("")
      end

      def load_captor(format)
        if (match = format.match(/\Acustom:(?<path>.+?):(?<class_name>.+)\z/))
          load_custom_captor(match[:path], match[:class_name])
        else
          captor = captors[format]
          raise GergichError, "Unrecognized format `#{format}`" unless captor

          captor
        end
      end

      def load_custom_captor(path, class_name)
        begin
          require path
        rescue LoadError
          raise GergichError, "unable to load custom format from `#{path}`"
        end
        begin
          const_get(class_name)
        rescue NameError
          raise GergichError, "unable to find custom format class `#{class_name}`"
        end
      end

      def captors
        @captors ||= {}
      end
    end
  end
end

Dir[File.dirname(__FILE__) + "/capture/*.rb"].sort.each { |file| require file }
