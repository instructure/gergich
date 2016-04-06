module Gergich
  module Capture
    class BaseCapture
      def self.inherited(subclass)
        name = subclass.name
        # borrowed from AS underscore, since we may not have it
        name.gsub!(/.*::|Capture\z/, "")
        name.gsub!(/([A-Z\d]+)([A-Z][a-z])/, "\\1_\\2")
        name.gsub!(/([a-z\d])([A-Z])/, "\\1_\\2")
        name.tr!("-", "_")
        name.downcase!
        Capture.captors[name] = subclass
      end
    end

    class << self
      def run(format, command)
        captor = load_captor(format)

        exit_code, output = run_command(command)
        comments = captor.new.run(output.gsub(/\e\[\d+m/m, ""))

        draft = Gergich::Draft.new
        skip_paths = (ENV["SKIP_PATHS"] || "").split(",")
        comments.each do |comment|
          next if skip_paths.any? { |path| comment[:path].start_with?(path) }
          draft.add_comment comment[:path], comment[:position],
                            comment[:message], comment[:severity]
        end

        exit_code
      end

      def run_command(command)
        exit_code = 0

        if command == "-"
          output = wiretap($stdin)
        else
          IO.popen("#{command} 2>&1", "r+") do |io|
            output = wiretap(io)
          end
          exit_code = $CHILD_STATUS.exitstatus
        end

        [exit_code, output]
      end

      def wiretap(io)
        output = ""
        io.each do |line|
          puts line
          output << line
        end
        output
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

Dir[File.dirname(__FILE__) + "/capture/*.rb"].each { |file| require file }
