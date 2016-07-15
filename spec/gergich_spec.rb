require_relative "../lib/gergich"

RSpec.describe Gergich::API do
  let(:result) { double(:result, { body: "Not Found: 1234" }) }

  before :each do
    allow(HTTParty).to receive(:send).and_return(result)
    allow(described_class).to receive(:prepare_options).and_return({})
  end

  it "provides helpful error when Change-Id not found" do
    expect { described_class.get("/a/changes/1234") }.to raise_error(/Cannot find Change-Id: 1234/)
  end
end

RSpec.describe Gergich::Draft do
  let!(:draft) do
    commit = double(:commit, {
      files: [
        "foo.rb",
        "bar/baz.lol"
      ],
      revision_id: "test",
      change_id: "test"
    })
    described_class.new commit
  end

  after do
    draft.reset!
  end

  describe "#info" do
    subject { draft.info }

    describe "[:comments]" do
      subject { super()[:comments] }

      it "includes file comments" do
        draft.add_comment "foo.rb", 1, "fix foo", "info"
        expect(subject).to eq({ "foo.rb" => [{ line: 1, message: "[INFO] fix foo" }] })
      end

      it "includes COMMIT_MSG comments" do
        draft.add_comment "/COMMIT_MSG", 1, "fix commit", "info"
        expect(subject).to eq({ "/COMMIT_MSG" => [{ line: 1, message: "[INFO] fix commit" }] })
      end

      it "doesn't include orphaned file comments" do
        draft.add_comment "invalid.rb", 1, "fix invalid", "info"
        expect(subject).to eq({})
      end
    end

    describe "[:cover_message]" do
      subject { super()[:cover_message] }

      it "includes the Code-Review score if negative" do
        draft.add_label "Code-Review", -1
        expect(subject).to match(/^-1/)
      end

      it "doesn't include the score if not negative" do
        draft.add_label "Code-Review", 0
        expect(subject).to_not match(/^0/)
      end

      it "includes explicitly added messages" do
        draft.add_message "this is good"
        draft.add_message "loljk it's terrible"
        expect(subject).to include("this is good\n\nloljk it's terrible")
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

        expect(subject).to eq({
          "QA-Review" => -1,
          "Code-Review" => -2
        })
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
