require_relative '../../lib/cover_messages'

RSpec.describe Gergich::CoverMessages do
  context "returns an array of at least size one" do
    %w[minus_two minus_one one_comment multiple_comments now_fixed].each do |category|
      it "for category '#{category}'" do
        results = Gergich::CoverMessages.send(category)
        expect(results).to be_a(Array)
        expect(results.length).to be > 0
      end
    end
  end

  context "negative scores" do
    context "properly reports" do
      it "for previous minus 1" do
        Gergich::CoverMessages.minus_one.each do |message|
          expect(Gergich::CoverMessages.previous_score_minus(message)).to be_truthy
        end
      end

      it "for previous minus 2" do
        Gergich::CoverMessages.minus_two.each do |message|
          expect(Gergich::CoverMessages.previous_score_minus(message)).to be_truthy
        end
      end
    end

    context "not reported" do
      it "for single comments" do
        Gergich::CoverMessages.one_comment.each do |message|
          expect(Gergich::CoverMessages.previous_score_minus(message)).to be_falsey
        end
      end

      it "for multiple comments" do
        Gergich::CoverMessages.multiple_comments.each do |message|
          expect(Gergich::CoverMessages.previous_score_minus(message)).to be_falsey
        end
      end

      it "does not report on now_fixed" do
        Gergich::CoverMessages.now_fixed.each do |message|
          expect(Gergich::CoverMessages.previous_score_minus(message)).to be_falsey
        end
      end
    end
  end
end
