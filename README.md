# Gergich

[![Gem Version](https://badge.fury.io/rb/gergich.svg)](https://rubygems.org/gems/gergich)
[![Dependency Status](https://gemnasium.com/badges/a2946a7849cd94f5ec0f4c3173a968f4.svg)](https://gemnasium.com/cc6fb44edee9fcf855cec82d3b6aed0f)
[![Build Status](https://travis-ci.org/instructure/gergich.svg?branch=master)](https://travis-ci.org/instructure/gergich)

Gergich is a command-line tool (and ruby lib) for easily posting comments
on a [Gerrit](https://www.gerritcodereview.com/) review from a CI
environment. It can be wired up to linters (rubocop, eslint, etc.) so that
you can get nice inline comments right on the Gerrit review. That way
developers don't have to go digging through CI logs to see why their
builds failed.

## How does it work?

Gergich maintains a little sqlite db of any draft comments/labels/etc.
for the current patchset (defined by revision+ChangeId). This way
different processes can all contribute to the review. For example,
various linters add inline comments, and when the CI build finishes,
Gergich publishes the review to Gerrit.

## Limitations

Because everything is synchronized/stored in a local sqlite db, you
should only call Gergich from a single box/build per patchset. Gergich
does a check when publishing to ensure he hasn't already posted on this
patchset before; if he has, publish will be a no-op. This protects
against reposts (say, on a retrigger), but it does mean that you shouldn't
have completely different builds posting Gergich comments on the same
revision, unless you set up different credentials for each.

## Installation

Add the following to your Gemfile (perhaps in your `:test` group?):

```ruby
gem "gergich"
```

To use Gergich, you'll need a Gerrit user whose credentials it'll use
(ideally not your own). With your shiny new username and password in hand,
set `GERGICH_USER` and `GERGICH_KEY` accordingly in your CI environment.

Additionally, Gergich needs to know where your Gerrit installation
lives, so be sure to set `GERRIT_BASE_URL` (e.g.
`https://gerrit.example.com`) or `GERRIT_HOST` (e.g. `gerrit.example.com`).

Lastly, if you have no .git directory in CI land (say if you are building
in docker and want to keep your images small), you also need to set
`GERRIT_CHANGE_ID` and `GERRIT_PATCHSET_REVISION`. If you use Jenkins and
the gerrit-trigger plugin, typcially all `GERRIT_*` vars will already be
set, it's just a matter of plumbing them down to docker.

## Usage

Run `gergich help` for detailed information about all supported commands.
In your build scripts, you'll typically be using `gergich comment`,
`gergich capture` and `gergich publish`. Comments are stored locally in a
sqlite database until you publish. This way you can queue up comments from
many disparate processes. Comments are published to `HEAD`'s corresponding
patchset in Gerrit (based on Change-Id + `<sha>`)

### `gergich comment <comment_data>`

`<comment_data>` is a JSON object (or array of objects). Each comment
object should have the following properties:

* **path** - the relative file path, e.g. "app/models/user.rb"
* **position** - either a number (line) or an object (range). If an object,
  must have the following numeric properties:
  * start_line
  * start_character
  * end_line
  * end_character
* **message** - the text of the comment
* **severity** - `"info"|"warn"|"error"` - this will automatically prefix
  the comment (e.g. `"[ERROR] message here"`), and the most severe comment
  will be used to determine the overall `Code-Review` score (0, -1, or -2
  respectively)

Note that a cover message and `Code-Review` score will be inferred from the
most severe comment.

#### Examples

```bash
gergich comment '{"path":"foo.rb","position":3,"severity":"error",
                  "message":"ಠ_ಠ"}'
gergich comment '{"path":"bar.rb","severity":"warn",
                  "position":{"start_line":3,"start_character":5,...},
                  "message":"¯\_(ツ)_/¯"}'
gergich comment '[{"path":"baz.rb",...}, {...}, {...}]'
```

### `gergich capture <format> <command>`

For common linting formats, `gergich capture` can be used to automatically
do `gergich comment` calls so you don't have to wire it up yourself.

`<format>` - One of the following:

* `rubocop`
* `eslint`
* `i18nliner`
* `custom:<path>:<class_name>` - file path and ruby class_name of a custom
  formatter.

`<command>` - The command to run whose output conforms to `<format>`.
Output from the command will still go to STDOUT, and Gergich will
preserve its exit status. If command is "-", Gergich will simply read
from STDIN and the exit status will always be 0.

#### Custom formatters:

To create a custom formatter, create a class that implements a `run`
method that takes a string of command output and returns an array of
comment hashes (see `gergich comment`'s `<comment_data>` format), e.g.

```ruby
class MyFormatter
  def run(output)
    output.scan(/^Oh noes! (.+?):(\d+): (.*)$/).map do |file, line, error|
      { path: file, message: error, position: line.to_i, severity: "error" }
    end
  end
end
```

#### Examples:

```bash
gergich capture rubocop "bundle exec rubocop"

gergich capture eslint eslint

gergich capture i18nliner "rake i18nliner:check"

gergich capture custom:./gergich/xss:Gergich::XSS "node script/xsslint"

docker-compose run --rm web eslint | gergich capture eslint -
# you might be interested in $PIPESTATUS[0]
```

### `gergich publish`

Publish all draft comments/labels/messages for this patchset. no-op if
there are none.

The cover message and `Code-Review` label (e.g. -2) are inferred from the
comments, but labels and messages may be manually set (via `gergich
message` and `gergich labels`)

## How do I test my changes?

Write tests of course, but also be sure to test it end-to-end via the
CLI... Run `gergich` for a list of commands, as well as help for each
command. There's also a `citest` thing that we run on our Jenkins that
ensures each CLI command succeeds, but it doesn't test all branches for
each command.

After running a given command, you can run `gergich status` to see the
current draft of the review (what will be sent to Gerrit when you do
`gergich publish`).

You can even do a test `publish` to Gerrit, if you have valid Gerrit
credentials in `GERGICH_USER` / `GERGICH_KEY`. It infers the Gerrit patchset
from the working directory, which may or may not correspond to something
actually in Gerrit, so YMMV. That means you can post to a Gergich commit
in Gerrit, or if you run it from another project's directory, you can post
to its Gerrit revision.
