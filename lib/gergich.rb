require "sqlite3"
require "json"
require "fileutils"
require "httparty"

GERGICH_REVIEW_LABEL = ENV.fetch("GERGICH_REVIEW_LABEL", "Code-Review")
GERGICH_USER = ENV.fetch("GERGICH_USER", "gergich")
GERGICH_GIT_PATH = ENV.fetch("GERGICH_GIT_PATH", ".")

GergichError = Class.new(StandardError)

module Gergich
  def self.git(args)
    Dir.chdir(GERGICH_GIT_PATH) do
      `git #{args} 2>/dev/null`
    end
  end

  class Commit
    attr_reader :ref

    def initialize(ref = "HEAD", revision_number = nil)
      @ref = ref
      @revision_number = revision_number
    end

    def info
      @info ||= begin
        output = Gergich.git("log -1 #{ref}")
        /\Acommit (?<revision_id>[0-9a-f]+).*^\s*Change-Id: (?<change_id>\w+)/m =~ output
        { revision_id: revision_id, change_id: change_id }
      end
    end

    def files
      @files ||= Gergich.git("diff-tree --no-commit-id --name-only -r #{ref}").split
    end

    def revision_id
      info[:revision_id]
    end

    def revision_number
      @revision_number ||= begin
        gerrit_info = API.get("/changes/?q=#{change_id}&o=ALL_REVISIONS")[0]
        raise GergichError, "Gerrit patchset not found" unless gerrit_info
        gerrit_info["revisions"][revision_id]["_number"]
      end
    end

    def change_id
      info[:change_id]
    end
  end

  class Review
    attr_reader :commit, :draft

    def initialize(commit = Commit.new, draft = Draft.new)
      @commit = commit
      @draft = draft
    end

    # Public: publish all draft comments/labels/messages
    def publish!(allow_repost = false)
      # only publish if we have something to say or if our last score was negative
      return unless anything_to_publish? || previous_score_negative?

      # TODO: rather than just bailing, fetch the comments and only post
      # ones that don't exist (if any)
      return if already_commented? && !allow_repost

      API.post(generate_url, generate_payload)

      # because why not
      if rand < 0.01 && GERGICH_USER == "gergich"
        API.put("/accounts/self/name", { name: whats_his_face }.to_json)
      end

      review_info
    end

    def anything_to_publish?
      !review_info[:comments].empty? ||
        !review_info[:cover_message].empty? ||
        review_info[:labels].any? { |_, score| score != 0 }
    end

    # Public: show the current draft for this patchset
    def status
      puts "Gergich DB: #{draft.db_file}"
      unless anything_to_publish?
        puts "Nothing to publish"
        return
      end

      puts "ChangeId: #{commit.change_id}"
      puts "Revision: #{commit.revision_id}"

      puts
      review_info[:labels].each do |name, score|
        puts "#{name}: #{score}"
      end

      puts
      puts "Cover Message:"
      puts review_info[:cover_message]

      unless review_info[:comments].empty?
        puts
        puts "Inline Comments:"
        puts

        review_info[:comments].each do |file, comments|
          comments.each do |comment|
            puts "#{file}:#{comment[:line] || comment[:range]['start_line']}\n#{comment[:message]}"
          end
        end
      end
    end

    def previous_score
      last_message = my_messages
        .sort_by { |message| message["date"] }
        .last

      text = last_message && last_message["message"] || ""
      text =~ /^-[12]/

      ($& || "").to_i
    end

    def previous_score_negative?
      previous_score < 0
    end

    def already_commented?
      revision_number = commit.revision_number
      my_messages.any? { |message| message["_revision_number"] == revision_number }
    end

    def my_messages
      @messages ||= API.get("/changes/#{commit.change_id}/detail")["messages"]
        .select { |message| message["author"] && message["author"]["username"] == GERGICH_USER }
    end

    def whats_his_face
      "#{%w[Garry Larry Terry Jerry].sample} Gergich (Bot)"
    end

    def review_info
      @review_info ||= draft.info
    end

    def generate_url
      "/changes/#{commit.change_id}/revisions/#{commit.revision_id}/review"
    end

    def generate_payload
      {
        message: review_info[:cover_message],
        labels: review_info[:labels],
        comments: review_info[:comments],
        # we don't want the post to fail if another
        # patchset was created in the interim
        strict_labels: false
      }.to_json
    end
  end

  class API
    class << self
      def get(url)
        perform(:get, url)
      end

      def post(url, body)
        perform(:post, url, body)
      end

      def put(url, body)
        perform(:put, url, body)
      end

      private

      def perform(method, url, body = nil)
        options = base_options
        if body
          options[:headers] = { "Content-Type" => "application/json" }
          options[:body] = body
        end
        ret = HTTParty.send(method, url, options).body
        if ret.sub!(/\A\)\]\}'\n/, "") && ret =~ /\A("|\[|\{)/
          JSON.parse(ret)
        else
          raise("Non-JSON response: #{ret}")
        end
      end

      def base_uri
        @base_url ||= \
          ENV["GERRIT_BASE_URL"] ||
          ENV.key?("GERRIT_HOST") && "https://#{ENV['GERRIT_HOST']}" ||
          raise(GergichError, "need to set GERRIT_BASE_URL or GERRIT_HOST")
      end

      def base_options
        {
          base_uri: base_uri + "/a",
          digest_auth: {
            username: GERGICH_USER,
            password: ENV.fetch("GERGICH_KEY")
          }
        }
      end
    end
  end

  class Draft
    SEVERITY_MAP = {
      "info" => 0,
      "warn" => -1,
      "error" => -2
    }.freeze

    attr_reader :db, :commit

    def initialize(commit = Commit.new)
      @commit = commit
    end

    def db_file
      @db_file ||= File.expand_path("/tmp/#{GERGICH_USER}-#{commit.revision_id}.sqlite3")
    end

    def db
      @db ||= begin
        db_exists = File.exist?(db_file)
        db = SQLite3::Database.new(db_file)
        db.results_as_hash = true
        create_db_schema! unless db_exists
        db
      end
    end

    def reset!
      FileUtils.rm_f(db_file)
    end

    def create_db_schema!
      db.execute <<-SQL
        CREATE TABLE comments (
          path VARCHAR,
          position VARCHAR,
          message VARCHAR,
          severity VARCHAR
        );
      SQL
      db.execute <<-SQL
        CREATE TABLE labels (
          name VARCHAR,
          score INTEGER
        );
      SQL
      db.execute <<-SQL
        CREATE TABLE messages (
          message VARCHAR
        );
      SQL
    end

    # Public: add a label to the draft
    #
    # name     - the label name, e.g. "Code-Review"
    # score    - the score, e.g. "-1"
    #
    # You can set add the same label multiple times, but the lowest score
    # for a given label will be used. This also applies to the inferred
    # "Code-Review" score from comments; if it is non-zero, it will trump
    # a higher score set here.
    def add_label(name, score)
      score = score.to_i
      raise GergichError, "invalid score" if score < -2 || score > 1
      raise GergichError, "can't set #{name}" if %w[Verified].include?(name)

      db.execute "INSERT INTO labels (name, score) VALUES (?, ?)",
                 [name, score]
    end

    # Public: add something to the cover message
    #
    # These messages will appear after the "-1" (or whatever)
    def add_message(message)
      db.execute "INSERT INTO messages (message) VALUES (?)", [message]
    end

    #
    # Public: add an inline comment to the draft
    #
    # path     - the relative file path, e.g. "app/models/user.rb"
    # position - either a Fixnum (line number) or a Hash (range). If a
    #            Hash, must have the following Fixnum properties:
    #              * start_line
    #              * start_character
    #              * end_line
    #              * end_character
    # message  - the text of the comment
    # severity - "info"|"warn"|"error" - this will automatically prefix
    #            the comment (e.g. "[ERROR] message here"), and the most
    #            severe comment will be used to determine the overall
    #            Code-Review score (0, -1, or -2 respectively)
    def add_comment(path, position, message, severity)
      raise GergichError, "invalid position `#{position}`" unless valid_position?(position)
      position = position.to_json if position.is_a?(Hash)
      raise GergichError, "invalid severity `#{severity}`" unless SEVERITY_MAP.key?(severity)
      raise GergichError, "no message specified" unless message.is_a?(String) && !message.empty?

      db.execute "INSERT INTO comments (path, position, message, severity) VALUES (?, ?, ?, ?)",
                 [path, position, message, severity]
    end

    POSITION_KEYS = %w[end_character end_line start_character start_line].freeze
    def valid_position?(position)
      (
        position.is_a?(Fixnum) && position >= 0
      ) || (
        position.is_a?(Hash) && position.keys.sort == POSITION_KEYS &&
        position.values.all? { |v| v.is_a?(Fixnum) && v >= 0 }
      )
    end

    def labels
      @labels ||= begin
        labels = { GERGICH_REVIEW_LABEL => 0 }
        db.execute("SELECT name, MIN(score) AS score FROM labels GROUP BY name").each do |row|
          labels[row["name"]] = row["score"]
        end
        score = min_comment_score
        labels[GERGICH_REVIEW_LABEL] = score if score < 0 && score < labels[GERGICH_REVIEW_LABEL]
        labels
      end
    end

    def all_comments
      @all_comments ||= begin
        comments = {}

        sql = "SELECT path, position, message, severity FROM comments"
        db.execute(sql).each do |row|
          inline = changed_files.include?(row["path"])
          comments[row["path"]] ||= FileReview.new(row["path"], inline)
          comments[row["path"]].add_comment(row["position"],
                                            row["message"],
                                            row["severity"])
        end

        comments.values
      end
    end

    def inline_comments
      all_comments.select(&:inline)
    end

    def other_comments
      all_comments.reject(&:inline)
    end

    def min_comment_score
      all_comments.inject(0) { |a, e| [a, e.min_score].min }
    end

    def changed_files
      @changed_files ||= commit.files + ["/COMMIT_MSG"]
    end

    def info
      @info ||= begin
        comments = Hash[inline_comments.map { |file| [file.path, file.to_a] }]

        {
          comments: comments,
          cover_message: cover_message,
          total_comments: all_comments.map(&:count).inject(&:+),
          score: labels[GERGICH_REVIEW_LABEL],
          labels: labels
        }
      end
    end

    def messages
      db.execute("SELECT message FROM messages").map { |row| row["message"] }
    end

    def orphaned_message
      message = "NOTE: I couldn't create inline comments for everything. " \
                "Although this isn't technically part of your commit, you " \
                "should still check it out (i.e. side effects or auto-" \
                "generated from stuff you *did* change):"

      other_comments.each do |file|
        file.comments.each do |position, comments|
          comments.each do |comment|
            line = position.is_a?(Fixnum) ? position : position["start_line"]
            message << "\n\n#{file.path}:#{line}: #{comment}"
          end
        end
      end

      message
    end

    def cover_message
      score = labels[GERGICH_REVIEW_LABEL]
      parts = messages
      parts.unshift score.to_s if score < 0

      parts << orphaned_message unless other_comments.empty?
      parts.join("\n\n")
    end
  end

  class FileReview
    attr_accessor :path, :comments, :inline, :min_score

    def initialize(path, inline)
      self.path = path
      self.comments = Hash.new { |hash, position| hash[position] = [] }
      self.inline = inline
    end

    def add_comment(position, message, severity)
      position = position.to_i if position =~ /\A\d+\z/
      comments[position] << "[#{severity.upcase}] #{message}"
      self.min_score = [min_score || 0, Draft::SEVERITY_MAP[severity]].min
    end

    def count
      comments.size
    end

    def to_a
      comments.map do |position, position_comments|
        comment = position_comments.join("\n\n")
        position_key = position.is_a?(Fixnum) ? :line : :range
        position = JSON.parse(position) unless position.is_a?(Fixnum)
        {
          :message => comment,
          position_key => position
        }
      end
    end
  end
end
