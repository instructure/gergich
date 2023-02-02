# frozen_string_literal: true

require_relative "../cli"

ENV["GERGICH_USER"] = ENV.fetch("MASTER_BOUNCER_USER", "master_bouncer")
ENV["GERGICH_KEY"] = ENV["MASTER_BOUNCER_KEY"] || error("no MASTER_BOUNCER_KEY set")
MASTER_BOUNCER_REVIEW_LABEL = ENV.fetch("GERGICH_REVIEW_LABEL", "Code-Review")

require_relative "../../gergich"

PROJECT = ENV["GERRIT_PROJECT"] || error("no GERRIT_PROJECT set")
# TODO: time-based thresholds
WARN_DISTANCE = ENV.fetch("MASTER_BOUNCER_WARN_DISTANCE", 50).to_i
ERROR_DISTANCE = ENV.fetch("MASTER_BOUNCER_ERROR_DISTANCE", 100).to_i

def potentially_mergeable_changes
  url = "/changes/?q=status:open+" \
        "p:#{PROJECT}+" \
        "label:Verified=1+" \
        "branch:master" \
        "&o=CURRENT_REVISION"
  changes = Gergich::API.get(url)
  changes.reject { |c| c["subject"] =~ /\Awip($|\W)/i }
end

def maybe_bounce_commit!(commit)
  draft = Gergich::Draft.new(commit)
  draft.reset!

  distance = Gergich.git("rev-list origin/master ^#{commit.ref} --count").to_i
  detail = "#{distance} commits behind master"

  score = 0
  message = nil
  if distance > ERROR_DISTANCE
    score = -2
    message = "This commit is probably not safe to merge (#{detail}). You'll " \
              "need to rebase it to ensure all the tests still pass."
  elsif distance > WARN_DISTANCE
    score = -1
    message = "This commit may not be safe to merge (#{detail}). Please " \
              "rebase to make sure all the tests still pass."
  end

  review = Gergich::Review.new(commit, draft)
  current_score = review.current_score

  puts "#{detail}, " + (score == current_score ?
                        "score still #{score}" :
                        "changing score from #{current_score} to #{score}")

  # since we run on a daily cron, we might be checking the same patchset
  # many times, so bail if nothing has changed
  return if score == current_score

  draft.add_label MASTER_BOUNCER_REVIEW_LABEL, score
  draft.add_message message if message

  # otherwise we always publish ... even in the score=0 case it's
  # important, as we might be undoing a previous negative score.
  # similarly, over time the same patchset will become more out of date,
  # so we allow_repost (so to speak) so we can add increasingly negative
  # reviews
  review.publish!(allow_repost: true)
end

commands = {}

commands["check"] = {
  summary: "Check the current commit's age",
  action: -> {
    maybe_bounce_commit! Gergich::Commit.new
  },
  help: -> {
    <<~TEXT
      master_bouncer check

      Check the current commit's age, and bounce it if it's too old (-1 or -2,
      depending on the threshold)
    TEXT
  }
}

commands["check_all"] = {
  summary: "Check the age of all potentially mergeable changes",
  action: -> {
    Gergich.git("fetch")
    gerrit_host = ENV["GERRIT_HOST"] || error("No GERRIT_HOST set")

    changes = potentially_mergeable_changes
    next if ENV["DRY_RUN"]

    changes.each do |change|
      sha = change["current_revision"] || next
      revinfo = change["revisions"][sha]
      refspec = revinfo["ref"]
      number = revinfo["_number"]

      print "Checking g/#{change['_number']}... "
      Gergich.git("fetch ssh://#{gerrit_host}:29418/#{PROJECT} #{refspec}")

      maybe_bounce_commit! Gergich::Commit.new(sha, number)
      sleep 1
    end
  },
  help: -> {
    <<~TEXT
      master_bouncer check_all

      Check all open Verified+1 patchsets and bounce any that are too old.
    TEXT
  }
}

run_app commands
