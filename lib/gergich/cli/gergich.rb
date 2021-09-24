# frozen_string_literal: true

require_relative "../cli"
require_relative "../../gergich"

CI_TEST_ARGS = {
  "comment" => [
    [
      { path: "foo.rb", position: 3, severity: "error", message: "ಠ_ಠ" },
      { path: "/COMMIT_MSG", position: 1, severity: "info", message: "cool story bro" },
      { path: "/COMMIT_MSG", severity: "info", message: "lol",
        position: { start_line: 1, start_character: 1, end_line: 1, end_character: 2 } }
    ].to_json
  ],
  "label" => ["Code-Review", 1],
  "message" => ["this is a test"],
  "capture" => ["rubocop", format("echo %<output>s", output: Shellwords.escape(<<~OUTPUT))]
    bin/gergich:47:8: C: Prefer double-quoted strings
    if ENV['DEBUG']
           ^^^^^^^
    1 file inspected, 35 offenses detected, 27 offenses auto-correctable
  OUTPUT
}.freeze

def run_ci_test!(all_commands)
  ENV["GERGICH_CHANGE_NAME"] = "0"
  commands_to_test = all_commands - %w[citest reset publish status]
  commands_to_test << "status" # put it at the end, so we maximize the stuff it tests

  commands = commands_to_test.map { |command| [command, CI_TEST_ARGS[command] || []] }
  commands.concat(all_commands.map { |command| ["help", [command]] })

  # after running our test commands, reset and publish frd:
  commands << ["reset"]
  # Note that while gergich should always be able to vote on these labels, he may be used to
  # vone on other branches depending on project usage and project-specific permissions
  commands << ["label", ["Lint-Review", 1]]
  commands << ["label", ["Code-Review", 1]] # Not all projects have Lint-Review
  commands << ["message", ["\`gergich citest\` checks out :thumbsup: :mj:"]]
  commands << ["publish"]

  commands.each do |command, args = []|
    arglist = args.map { |arg| Shellwords.escape(arg.to_s) }
    output = `bundle exec gergich #{command} #{arglist.join(" ")} 2>&1`
    unless $CHILD_STATUS.success?
      error "`gergich citest` failed on step `#{command}`:\n\n#{output.gsub(/^/, '  ')}\n"
    end
  end
end

commands = {}

commands["reset"] = {
  summary: "Clear out pending comments/labels/messages for this patchset",
  action: -> {
    Gergich::Draft.new.reset!
  },
  help: -> {
    <<~TEXT
      gergich reset

      Clear out the draft for this patchset. Useful for testing.
    TEXT
  }
}

commands["publish"] = {
  summary: "Publish the draft for this patchset",
  action: -> {
    if (data = Gergich::Review.new.publish!)
      puts "Published #{data[:total_comments]} comments, set score to #{data[:score]}"
    else
      puts "Nothing to publish"
    end
  },
  help: -> {
    <<~TEXT
      gergich publish

      Publish all draft comments/labels/messages for this patchset. no-op if
      there are none.

      The cover message and Code-Review label (e.g. -2) are inferred from the
      comments, but labels and messages may be manually set (via `gergich
      message` and `gergich labels`)
    TEXT
  }
}

commands["status"] = {
  summary: "Show the current draft for this patchset",
  action: -> {
    Gergich::Review.new.status
  },
  help: -> {
    <<~TEXT
      gergich status

      Show the current draft for this patchset

      Display any labels, cover messages and inline comments that will be set
      as part of this review.
    TEXT
  }
}

commands["comment"] = {
  summary: "Add one or more draft comments to this patchset",
  action: ->(comment_data) {
    comment_data = begin
      JSON.parse(comment_data)
    rescue JSON::ParserError
      error("Unable to parse <comment_data> json", "comment")
    end
    comment_data = [comment_data] unless comment_data.is_a?(Array)

    draft = Gergich::Draft.new
    comment_data.each do |comment|
      draft.add_comment comment["path"],
                        comment["position"],
                        comment["message"],
                        comment["severity"]
    end
  },
  help: -> {
    <<~TEXT
      gergich comment <comment_data>

      <comment_data> is a JSON object (or array of objects). Each comment object
      should have the following properties:
        path     - the relative file path, e.g. "app/models/user.rb"
        position - either a number (line) or an object (range). If an object,
                   must have the following numeric properties:
                     * start_line
                     * start_character
                     * end_line
                     * end_character
        message  - the text of the comment
        severity - "info"|"warn"|"error" - this will automatically prefix the
                   comment (e.g. "[ERROR] message here"), and the most severe
                   comment will be used to determine the overall Code-Review
                   score (0, -1, or -2 respectively)

      Note that a cover message and Code-Review score will be inferred from the
      most severe comment.

      Examples
          gergich comment '{"path":"foo.rb","position":3,"severity":"error",
                            "message":"ಠ_ಠ"}'
          gergich comment '{"path":"bar.rb","severity":"warn",
                            "position":{"start_line":3,"start_character":5,...},
                            "message":"¯\\_(ツ)_/¯"}'
          gergich comment '[{"path":"baz.rb",...}, {...}, {...}]'
    TEXT
  }
}

commands["message"] = {
  summary: "Add a draft cover message to this patchset",
  action: ->(message) {
    draft = Gergich::Draft.new
    draft.add_message message
  },
  help: -> {
    <<~TEXT
      gergich message <message>

      <message> will be appended to existing cover messages (inferred or manually
      added) for this patchset.
    TEXT
  }
}

commands["label"] = {
  summary: "Add a draft label (e.g. Code-Review -1) to this patchset",
  action: ->(label, score) {
    Gergich::Draft.new.add_label label, score
  },
  help: -> {
    <<~TEXT
      gergich label <label> <score>

      Add a draft label to this patchset. If the same label is set multiple
      times, the lowest score will win.

      <label>  - a valid label (e.g. "Code-Review")
      <score>  - a valid score (e.g. -1)
    TEXT
  }
}

commands["capture"] = {
  summary: "Run a command and translate its output into `gergich comment` calls",
  action: ->(format, command) {
    require_relative "../../gergich/capture"
    status, = Gergich::Capture.run(format, command)
    exit status
  },
  help: -> {
    <<~TEXT
      gergich capture <format> <command>

      For common linting formats, `gergich capture` can be used to automatically
      do `gergich comment` calls so you don't have to wire it up yourself.

      <format>        - One of the following:
                        * brakeman
                        * rubocop
                        * eslint
                        * i18nliner
                        * flake8
                        * stylelint
                        * yamllint
                        * custom:<path>:<class_name> - file path and ruby
                          class_name of a custom formatter.

      <command>       - The command to run whose output conforms to <format>.
                        Output from the command will still go to STDOUT, and
                        Gergich will preserve its exit status.
                        If command is "-", Gergich will simply read from STDIN
                        and the exit status will always be 0.

      Examples:
          gergich capture rubocop "bundle exec rubocop"

          gergich capture eslint eslint

          gergich capture i18nliner "rake i18nliner:check"

          gergich capture custom:./gergich/xss:Gergich::XSS "node script/xsslint"

          docker-compose run --rm web eslint | gergich capture eslint -
          # you might be interested in $PIPESTATUS[0]
    TEXT
  }
}

commands["citest"] = {
  summary: "Do a full gergich test based on the current commit",
  action: -> {
    # automagically test any new command that comes along
    run_ci_test!(commands.keys)
  },
  help: -> {
    <<~TEXT
      gergich citest

      You shouldn't need to run this locally, it runs on jenkins. It does the
      following:

      1. runs all the gergich commands (w/ dummy data)
      2. ensure all `help` commands work
      3. ensures gergich status is correct
      4. resets
      5. posts an actual +1
      6. publishes
    TEXT
  }
}

run_app commands
