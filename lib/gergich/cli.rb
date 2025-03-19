# frozen_string_literal: true

require "shellwords"
require "English"

$stdout.sync = true
$stderr.sync = true

def info(text)
  puts text
  exit
end

def script_name
  $PROGRAM_NAME.sub(%r{.*/}, "")
end

def usage(content = nil)
  "Usage: #{script_name} <command> [<args>...]\n" +
    (content ? "\n#{content}\n\n" : "") +
    "Tip: run `#{script_name} help <command>` for more info"
end

def error(text)
  warn "\e[31mError:\e[0m #{text}"
  warn usage
  exit 1
end

def help_command(commands)
  {
    action: lambda { |subcommand = "help"|
      subcommand_info = commands[subcommand]
      if !subcommand_info
        error "Unrecognized command `#{subcommand}`"
      elsif (help_text = subcommand_info[:help])
        info help_text.respond_to?(:call) ? help_text.call : help_text
      else
        error "No help available for `#{subcommand}`"
      end
    },
    help: lambda {
      indentation = commands.keys.map(&:size).max
      commands_help = commands
                      .to_a
                      .sort_by(&:first)
                      .filter_map do |key, data|
        "#{key.ljust(indentation)} - #{data[:summary]}" if data[:summary]
      end

      usage(commands_help.join("\n"))
    }
  }
end

def run_command(action)
  params = action.parameters
  params.each_with_index do |(type, name), i|
    error "No <#{name}> specified" if i >= ARGV.size && type == :req
  end
  if ARGV.size > params.size
    extra_args = ARGV[params.size, ARGV.size].map { |a| "`#{Shellwords.escape(a)}`" }
    error "Extra arg(s) #{extra_args.join(" ")}"
  end
  action.call(*ARGV)
end

def run_app(commands)
  commands["help"] = help_command(commands)
  command = ARGV.shift || "help"

  if commands[command]
    begin
      action = commands[command][:action]
      run_command(action)
    rescue GergichError => e
      error e.message
    rescue => e
      error "Unhandled exception: #{e}\n#{e.backtrace.join("\n")}"
    end
  else
    error "Unrecognized command `#{command}`"
  end
end
