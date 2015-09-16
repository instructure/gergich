# Gergich

CLI and little ruby lib for programatically posting reviews to gerrit.
Used by canvas/catalog/bridge to post inline comments from linters
on jenkins (rubocop, i18n, etc)

## How does it work?

Gergich maintains a little sqlite db of any draft comments/labels/etc.
for the current patchset (defined by revision+ChangeId). This way
different processes can all contribute to the review. For example,
various linters add inline comments, and when the jenkins build finishes
gergich publishes the review to gerrit.

## Limitations

Because everything is synchronized/stored in a local sqlite db, you
should only call gergich from a single box/build per patchset. For
example, canvas should only run gergich on the aux build (and just one
aux build, at that). Gergich does a check when publishing to ensure he
hasn't already posted on this patchset before; if he has, publish will be
a no-op.

## How do I test my changes?

Write tests of course, but also be sure to test it end-to-end via the
CLI... Run `bin/gergich` for a list of commands, as well as help for each
command. There's also a `citest` thing that runs on jenkins that ensures
each CLI command succeeds, but it doesn't test all branches for each
command.

After running a given command, you can run `bin/gergich status` to see
the current draft of the review (what will be sent to gerrit when you
do `bin/gergich publish`).

You can even do a test `publish` to gerrit, if you have valid gerrit
credentials in GERGICH_USER / GERGICH_KEY. It infers the gerrit patchset
from the working directory, which may or may not correspond to something
actually in gerrit, so ymmv. That means you can post to a gergich commit
in gerrit, or if you run it from your canvas dir, you can post to a canvas
commit, etc.
