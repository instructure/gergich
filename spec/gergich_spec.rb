# frozen_string_literal: true

require "httparty"

RSpec.describe Gergich::API do
  context "with bad change-id" do
    let(:result) { double(:result, body: "Not Found: 1234") }

    before do
      allow(HTTParty).to receive(:send).and_return(result)
      allow(described_class).to receive(:prepare_options).and_return({})
    end

    it "provides helpful error when Change-Id not found" do
      # Get ride of CI_TEST_RUN environment variable so the api preforms normally
      ENV["CI_TEST_RUN"] = nil
      expect { described_class.get("/a/changes/1234") }
        .to raise_error(/Cannot find Change-Id: 1234/)
    end
  end

  context "when GERGICH_DIGEST_AUTH exists" do
    it "uses digest auth" do
      original_basic_auth = ENV["GERGICH_DIGEST_AUTH"]
      ENV["GERGICH_DIGEST_AUTH"] = "1"
      original_gergich_key = ENV["GERGICH_KEY"]
      ENV["GERGICH_KEY"] = "foo"
      allow(described_class).to receive(:base_uri).and_return("https://gerrit.foobar.com")

      expect(described_class.send(:prepare_options, {}))
        .to match(
          hash_including(
            digest_auth: { username: "gergich", password: ENV["GERGICH_KEY"] }
          )
        )

      ENV["GERGICH_DIGEST_AUTH"] = original_basic_auth
      ENV["GERGICH_KEY"] = original_gergich_key
    end
  end

  context "when GERGICH_DIGEST_AUTH does not exist" do
    it "uses basic auth" do
      original_basic_auth = ENV["GERGICH_DIGEST_AUTH"]
      ENV["GERGICH_DIGEST_AUTH"] = nil
      original_gergich_key = ENV["GERGICH_KEY"]
      ENV["GERGICH_KEY"] = "foo"
      allow(described_class).to receive(:base_uri).and_return("https://gerrit.foobar.com")

      expect(described_class.send(:prepare_options, {}))
        .to match(hash_including(basic_auth: { username: "gergich", password: ENV["GERGICH_KEY"] }))

      ENV["GERGICH_DIGEST_AUTH"] = original_basic_auth
      ENV["GERGICH_KEY"] = original_gergich_key
    end
  end
end

RSpec.describe Gergich::Commit do
  before do
    allow(Gergich).to receive(:use_git?).and_return(false)
  end

  describe "#change_id" do
    it "supports branches with slashes" do
      allow(ENV).to receive(:[]).with("GERRIT_PATCHSET_REVISION").and_return("commit-ish")
      allow(ENV).to receive(:[]).with("GERRIT_PROJECT").and_return("spec-project")
      allow(ENV).to receive(:[]).with("GERRIT_BRANCH").and_return("releases/2017.11.17")
      allow(ENV).to receive(:[]).with("GERRIT_CHANGE_ID").and_return("dummychangeset")

      expect(described_class.new.change_id) # %2F = / and %7E = ~
        .to match("spec-project~releases%2F2017.11.17~dummychangeset")
    end
  end
end

RSpec.describe Gergich::Draft do
  let!(:draft) do
    commit = double(
      :commit,
      files: [
        "foo.rb",
        "bar/baz.lol"
      ],
      revision_id: "test",
      change_id: "test"
    )
    described_class.new commit
  end

  after do
    draft.reset!
  end

  describe "#GERGICH_DB_PATH" do
    it "uses the custom path" do
      original_db_path = ENV["GERGICH_DB_PATH"]
      ENV["GERGICH_DB_PATH"] = "/custom"

      expect(draft.db_file).to eq("/custom/gergich-test.sqlite3")

      ENV["GERGICH_DB_PATH"] = original_db_path
    end

    it "uses the default path" do
      expect(draft.db_file).to eq("/tmp/gergich-test.sqlite3")
    end
  end

  describe "#info" do
    subject { draft.info }

    describe "[:comments]" do
      subject { super()[:comments] }

      it "includes file comments" do
        draft.add_comment "foo.rb", 1, "fix foo", "info"
        expect(subject).to eq("foo.rb" => [{ line: 1, message: "[INFO] fix foo" }])
      end

      it "strips whitespace from filename" do
        draft.add_comment " foo.rb\n", 1, "fix foo", "info"
        expect(subject).to eq("foo.rb" => [{ line: 1, message: "[INFO] fix foo" }])
      end

      it "includes COMMIT_MSG comments" do
        draft.add_comment "/COMMIT_MSG", 1, "fix commit", "info"
        expect(subject).to eq("/COMMIT_MSG" => [{ line: 1, message: "[INFO] fix commit" }])
      end

      it "doesn't include orphaned file comments" do
        draft.add_comment "invalid.rb", 1, "fix invalid", "info"
        expect(subject).to eq({})
      end
    end

    describe "[:cover_message_parts]" do
      subject { super()[:cover_message_parts] }

      let(:message1) { "this is good" }
      let(:message2) { "loljk it's terrible" }

      it "includes explicitly added messages" do
        draft.add_message message1
        draft.add_message message2

        expect(subject).to include(message1)
        expect(subject).to include(message2)
      end

      context "when orphaned file comments exist" do
        let(:orphaned_comment) { "fix invalid" }

        before do
          draft.add_comment "invalid.rb", 1, orphaned_comment, "info"
        end

        it "includes orphan file message" do
          expect(subject.first).to match(/#{orphaned_comment}/)
        end
      end
    end

    describe "[:total_comments]" do
      subject { super()[:total_comments] }

      it "includes inline and orphaned comments" do
        draft.add_comment "foo.rb", 1, "fix foo", "info"
        draft.add_comment "invalid.rb", 1, "fix invalid", "info"
        expect(subject).to eq 2
      end
    end

    describe "[:labels]" do
      subject { super()[:labels] }

      it "uses the lowest score for each label" do
        draft.add_label "QA-Review", 1
        draft.add_label "QA-Review", -1
        draft.add_label "Code-Review", -2
        draft.add_label "Code-Review", 1

        expect(subject).to eq(
          "QA-Review" => -1,
          "Code-Review" => -2
        )
      end

      it "disallows \"Verified\"" do
        expect { draft.add_label "Verified", 1 }.to raise_error(/can't set Verified/)
      end

      it "disallows scores > 1" do
        expect { draft.add_label "Foo", 2 }.to raise_error(/invalid score/)
      end

      describe "[\"Code-Review\"]" do
        subject { super()["Code-Review"] }

        it "defaults to zero" do
          expect(subject).to eq(0)
        end

        it "is the lowest comment severity if not set" do
          draft.add_comment "foo.rb", 1, "fix foo", "info"
          draft.add_comment "foo.rb", 2, "fix foo", "error"
          draft.add_comment "foo.rb", 3, "fix foo", "warn"

          expect(subject).to eq(-2)
        end

        it "is trumped by a lower comment severity if negative" do
          draft.add_label "Code-Review", 1
          draft.add_comment "foo.rb", 1, "fix foo", "warn"

          expect(subject).to eq(-1)
        end

        it "is not trumped by a lower comment severity if zero" do
          draft.add_label "Code-Review", 1
          draft.add_comment "foo.rb", 1, "this is ok", "info"

          expect(subject).to eq(1)
        end

        it "is not trumped by a higher comment severity" do
          draft.add_label "Code-Review", -1
          draft.add_comment "foo.rb", 1, "this is ok", "info"

          expect(subject).to eq(-1)
        end
      end
    end
  end
end

RSpec.describe Gergich::Review do
  let(:change_id) { "test" }
  let!(:commit) do
    double(
      :commit,
      change_id: change_id,
      files: [
        "foo.rb",
        "bar/baz.lol"
      ],
      info: {},
      revision_id: change_id,
      revision_number: 1
    )
  end
  let!(:draft) do
    Gergich::Draft.new commit
  end
  let!(:review) { described_class.new(commit, draft) }

  after do
    draft.reset!
  end

  describe "#status" do
    subject { review.status }

    context "with nothing to publish" do
      before do
        allow(review).to receive(:anything_to_publish?).and_return(false)
      end

      it { expect { subject }.to output(include("Nothing to publish")).to_stdout }
    end

    context "with something to publish" do
      before do
        allow(review).to receive(:anything_to_publish?).and_return(true)
        allow(review).to receive(:already_commented?).and_return(false)
        allow(review).to receive(:generate_payload).and_return({})
        allow(review).to receive(:my_messages).and_return([])
      end

      it {
        expected_outputs = [
          "Project:",
          "Branch:",
          "Revision:",
          "ChangeId: #{change_id}",
          "Files:"
          # There's more... but this is good
        ]
        expect { subject }.to output(include(*expected_outputs)).to_stdout
      }
    end
  end

  describe "#publish!" do
    context "with nothing to publish" do
      before do
        allow(review).to receive(:anything_to_publish?).and_return(false)
      end

      it "does nothing" do
        expect(Gergich::API).not_to receive(:post)

        review.publish!
      end
    end

    context "with something to publish" do
      before do
        allow(review).to receive(:anything_to_publish?).and_return(true)
        allow(review).to receive(:already_commented?).and_return(false)
        allow(review).to receive(:generate_payload).and_return({})
      end

      it "publishes via the api" do
        expect(Gergich::API).to receive(:post)
        review.publish!
      end
    end
  end

  describe "#anything_to_publish?" do
    before do
      allow(review).to receive(:current_label).and_return("BAHA")
      allow(review).to receive(:current_label_revision).and_return("Revision trash stuff")
    end

    context "when no comments exist" do
      it "returns false" do
        allow(review).to receive(:new_score?).and_return(false)
        expect(review.anything_to_publish?).to eq false
      end
    end

    context "when comments exist" do
      it "returns true" do
        draft.info[:comments] = "Hello there this is a comment"
        expect(review.anything_to_publish?).to eq true
      end
    end
  end

  describe "#new_score?" do
    before do
      allow(review).to receive(:current_label_is_for_current_revision?).and_return(true)
      allow(review).to receive(:current_score).and_return(0)
    end

    context "when score is the same" do
      it "returns false" do
        draft.info[:score] = 0
        expect(review.new_score?).to eq false
      end
    end

    context "when score is different" do
      it "returns true" do
        draft.info[:score] = -1
        expect(review.new_score?).to eq true
      end
    end
  end

  describe "#upcoming_score" do
    context "when current_label_is_for_current_revision? is true" do
      it "returns the min value of draft.info[:score] and current_score" do
        allow(review).to receive(:current_label_is_for_current_revision?).and_return(true)
        allow(review).to receive(:current_score).and_return(0)
        review.draft.info[:score] = 1
        expect(review.upcoming_score).to eq 0
      end
    end

    context "when current_label_is_for_current_revision? is false" do
      it "returns the value of draft.info[:score]" do
        allow(review).to receive(:current_label_is_for_current_revision?).and_return(false)
        review.draft.info[:score] = 1
        expect(review.upcoming_score).to eq 1
      end
    end
  end

  describe "#cover_message" do
    context "when score is negative" do
      it "includes the Code-Review score if negative" do
        allow(review).to receive(:upcoming_score).and_return(-1)
        review.draft.add_label "Code-Review", -1
        expect(review.cover_message).to match(/^-1/)
      end
    end

    context "when score is non-negative" do
      it "doesn't include the score if not negative" do
        allow(review).to receive(:upcoming_score).and_return(0)
        draft.add_label "Code-Review", 0
        expect(subject).not_to match(/^0/)
      end
    end
  end
end
