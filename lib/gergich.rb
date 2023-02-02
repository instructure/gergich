# frozen_string_literal: true

require "erb"
require "json"
require "fileutils"
require "base64"

GERGICH_REVIEW_LABEL = ENV.fetch("GERGICH_REVIEW_LABEL", "Code-Review")
GERGICH_USER = ENV.fetch("GERGICH_USER", "gergich")
GERGICH_GIT_PATH = ENV.fetch("GERGICH_GIT_PATH", ".")

GergichError = Class.new(StandardError)

module Gergich
  def self.use_git?
    Dir.chdir(GERGICH_GIT_PATH) do
      system "git rev-parse --show-toplevel >/dev/null 2>&1"
    end
  end

  def self.git(args)
    Dir.chdir(GERGICH_GIT_PATH) do
      `git #{args} 2>/dev/null`
    end
  end

  class Commit
    attr_reader :ref

    def initialize(ref = ENV.fetch("GERRIT_PATCHSET_REVISION", "HEAD"), revision_number = nil)
      @ref = ref
      @revision_number = revision_number
    end

    def info
      @info ||= begin
        if Gergich.use_git?
          output = Gergich.git("log -1 #{ref}")
          /\Acommit (?<revision_id>[0-9a-f]+).*^\s*Change-Id: (?<change_id>\w+)/m =~ output
        else
          revision_id = ENV["GERRIT_PATCHSET_REVISION"] \
            || raise(GergichError, "No .git directory, and GERRIT_PATCHSET_REVISION not set")
          change_id = ENV["GERRIT_CHANGE_ID"] \
            || raise(GergichError, "No .git directory, and GERRIT_CHANGE_ID not set")
        end
        project = ENV["GERRIT_PROJECT"]
        branch = ENV["GERRIT_BRANCH"]

        { revision_id: revision_id, change_id: change_id, project: project, branch: branch }
      end
    end

    def files
      @files ||= if Gergich.use_git?
        Gergich.git("diff-tree --no-commit-id --name-only -r #{ref}").split
      else
        raw = API.get("/changes/#{change_id}/revisions/#{revision_id}/patch", raw: true)
        Base64.decode64(raw)
          .scan(%r{^diff --git a/.*? b/(.*?)$})
          .flatten
      end
    end

    def revision_id
      info[:revision_id]
    end

    def revision_number
      @revision_number ||= begin
        patchset_number = ENV["GERRIT_PATCHSET_NUMBER"]
        return patchset_number unless patchset_number.nil? # rubocop:disable Lint/NoReturnInBeginEndBlocks

        gerrit_info = API.get("/changes/?q=#{change_id}&o=ALL_REVISIONS")[0]
        raise GergichError, "Gerrit patchset not found" unless gerrit_info

        gerrit_info["revisions"][revision_id]["_number"]
      end
    end

    def change_id
      if info[:project] && info[:branch]
        "#{info[:project]}~#{ERB::Util.url_encode info[:branch]}~#{info[:change_id]}"
      else
        info[:change_id]
      end
    end
  end

  class Review
    attr_reader :commit, :draft

    def initialize(commit = Commit.new, draft = Draft.new)
      @commit = commit
      @draft = draft
    end

    # Public: publish all draft comments/labels/messages
    def publish!(allow_repost: false)
      # only publish if we have something to say or if our last score was negative
      return unless anything_to_publish?

      return if already_commented? && !allow_repost

      API.post(generate_url, generate_payload)

      review_info
    end

    def anything_to_publish?
      !review_info[:comments].empty? ||
        !review_info[:cover_message_parts].empty? ||
        new_score?
    end

    def new_score?
      if current_label_is_for_current_revision?
        review_info[:score] < current_score.to_i
      else
        true
      end
    end

    def upcoming_score
      if current_label_is_for_current_revision?
        [current_score.to_i, review_info[:score]].min
      else
        review_info[:score]
      end
    end

    # Public: show the current draft for this patchset
    def status
      puts "Gergich DB: #{draft.db_file}"
      unless anything_to_publish?
        puts "Nothing to publish"
        return
      end

      info = commit.info
      puts "Project: #{info[:project]}"
      puts "Branch: #{info[:branch]}"
      puts "Revision: #{info[:revision_id]} (##{commit.revision_number})"
      puts "ChangeId: #{commit.change_id}"
      puts "Files:"
      puts "  #{commit.files.join("\n  ")}"

      puts
      review_info[:labels].each do |name, score|
        puts "#{name}: #{score}"
      end

      puts
      puts "Cover Message:"
      puts cover_message

      return if review_info[:comments].empty?

      puts
      puts "Inline Comments:"
      puts

      review_info[:comments].each do |file, comments|
        comments.each do |comment|
          puts "#{file}:#{comment[:line] || comment[:range]['start_line']}\n#{comment[:message]}"
        end
      end
    end

    def multi_build_setup?
      # convert to boolean if this variable exists or not
      !ENV["GERGICH_COMMENT_PREFIX"].nil?
    end

    def unique_comment_prefix
      ENV["GERGICH_COMMENT_PREFIX"]
    end

    def already_commented?
      if multi_build_setup?
        my_messages_on_current_revision.any? do |message|
          message["message"] =~ /^#{unique_comment_prefix}/
        end
      else
        my_messages_on_current_revision.any?
      end
    end

    def my_messages_on_current_revision
      revision_number = commit.revision_number
      my_messages.select { |message| message["_revision_number"] == revision_number }
    end

    def my_messages
      @my_messages ||= API.get("/changes/#{commit.change_id}/detail")["messages"]
        .select { |message| message["author"] && message["author"]["username"] == GERGICH_USER }
    end

    # currently, cover message only supports the GERGICH_REVIEW_LABEL.
    # i.e., even if gergich has "Code-Review: -2"
    def current_label
      @current_label ||= API.get("/changes/#{commit.change_id}/detail")["labels"]
        .fetch(GERGICH_REVIEW_LABEL, {})
        .fetch("all", [])
        .select { |label| label["username"] == GERGICH_USER }
        .first
    end

    def current_label_date
      @current_label_date ||= current_label && current_label["date"]
    end

    # unfortunately, the revision is not a field in the label json.
    # however, we can match the label timestamp w/ one of our comment timestamps,
    # then grab the comment's revision.
    def current_label_revision
      return nil if my_messages.empty?

      @current_label_revision ||= begin
        date = current_label_date
        comment_for_current_label = my_messages.find { |message| message["date"] == date } ||
                                    my_messages.last
        comment_for_current_label["_revision_number"]
      end
    end

    def current_label_is_for_current_revision?
      current_label_revision == commit.revision_number
    end

    def current_score
      (current_label && current_label["value"]) || 0
    end

    def cover_message
      parts = review_info[:cover_message_parts]
      prefix = cover_message_prefix
      parts.unshift prefix if prefix != ""
      parts.join("\n\n")
    end

    def cover_message_prefix
      score = upcoming_score
      prefix_parts = []
      prefix_parts << unique_comment_prefix if multi_build_setup?
      prefix_parts << score if score.negative?
      prefix_parts.join(":")
      # [].join(":") => ""
      # [-2].join(":") => "-2"
      # ["some build prefix", -2].join(":") => "some build prefix:-2"
    end

    def review_info
      @review_info ||= draft.info
    end

    def generate_url
      "/changes/#{commit.change_id}/revisions/#{commit.revision_id}/review"
    end

    def generate_payload
      {
        message: cover_message,
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
      def get(url, options = {})
        perform(:get, url, options)
      end

      def post(url, body, options = {})
        perform(:post, url, options.merge(body: body))
      end

      def put(url, body, options = {})
        perform(:put, url, options.merge(body: body))
      end

      private

      def perform(method, url, options)
        # delay requiring httparty until here, to make local command line runs as fast as possible
        require "httparty"
        options = prepare_options(options)
        ret = HTTParty.send(method, url, options).body
        return ret if options[:raw]

        ret = ret.sub(/\A\)\]\}'\n/, "")
        if ret && ret =~ /\A("|\[|\{)/
          JSON.parse("[#{ret}]")[0] # array hack so we can parse a string literal
        elsif ret =~ /Not found: (?<change_id>.*)/i
          raise("Cannot find Change-Id: #{Regexp.last_match[:change_id]} at #{url}.\n"\
                "This is most likely due to this"\
                " Change-Id already being used"\
                " by an ABANDONED change.\n"\
                "To fix, `git commit --amend`,"\
                " remove the Change-Id line, and push again.")
        else
          raise("Non-JSON response: #{ret}")
        end
      end

      def base_uri
        @base_uri ||= \
          ENV["GERRIT_BASE_URL"] ||
          (ENV.key?("GERRIT_HOST") && "https://#{ENV['GERRIT_HOST']}") ||
          raise(GergichError, "need to set GERRIT_BASE_URL or GERRIT_HOST")
      end

      def auth_config
        if ENV["GERGICH_DIGEST_AUTH"]
          {
            digest_auth: {
              username: GERGICH_USER,
              password: ENV.fetch("GERGICH_KEY")
            }
          }
        else
          {
            basic_auth: {
              username: GERGICH_USER,
              password: ENV.fetch("GERGICH_KEY")
            }
          }
        end
      end

      def prepare_options(options)
        options = {
          base_uri: "#{base_uri}/a"
        }.merge(auth_config).merge(options)
        if options[:body]
          options[:headers] ||= {}
          options[:headers]["Content-Type"] ||= "application/json"
        end
        options
      end
    end
  end

  class Draft
    SEVERITY_MAP = {
      "info" => 0,
      "warn" => -1,
      "error" => -2
    }.freeze

    attr_reader :commit

    def initialize(commit = Commit.new)
      @commit = commit
    end

    def db_file
      @db_file ||= File.expand_path(
        "#{ENV.fetch('GERGICH_DB_PATH', '/tmp')}/#{GERGICH_USER}-#{commit.revision_id}.sqlite3"
      )
    end

    def db
      @db ||= begin
        require "sqlite3"
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
      stripped_path = path.strip

      raise GergichError, "invalid position `#{position}`" unless valid_position?(position)

      position = position.to_json if position.is_a?(Hash)
      raise GergichError, "invalid severity `#{severity}`" unless SEVERITY_MAP.key?(severity)
      raise GergichError, "no message specified" unless message.is_a?(String) && !message.empty?

      db.execute "INSERT INTO comments (path, position, message, severity) VALUES (?, ?, ?, ?)",
                 [stripped_path, position, message, severity]
    end

    POSITION_KEYS = %w[end_character end_line start_character start_line].freeze
    def valid_position?(position)
      (
        position.is_a?(Integer) && position >= 0
      ) || (
        position.is_a?(Hash) && position.keys.map(&:to_s).sort == POSITION_KEYS &&
        position.values.all? { |v| v.is_a?(Integer) && v >= 0 }
      )
    end

    def labels
      @labels ||= begin
        labels = { GERGICH_REVIEW_LABEL => 0 }
        db.execute("SELECT name, MIN(score) AS score FROM labels GROUP BY name").each do |row|
          labels[row["name"]] = row["score"]
        end
        score = min_comment_score
        labels[GERGICH_REVIEW_LABEL] = score if score < [0, labels[GERGICH_REVIEW_LABEL]].min
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
      all_comments.inject(0) { |acc, elem| [acc, elem.min_score].min }
    end

    def changed_files
      @changed_files ||= commit.files + ["/COMMIT_MSG"]
    end

    def info
      @info ||= begin
        comments = inline_comments.map { |file| [file.path, file.to_a] }.to_h

        {
          comments: comments,
          cover_message_parts: cover_message_parts,
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
      messages = ["NOTE: I couldn't create inline comments for everything. " \
                  "Although this isn't technically part of your commit, you " \
                  "should still check it out (i.e. side effects or auto-" \
                  "generated from stuff you *did* change):"]

      other_comments.each do |file|
        file.comments.each do |position, comments|
          comments.each do |comment|
            line = position.is_a?(Integer) ? position : position["start_line"]
            messages << "#{file.path}:#{line}: #{comment}"
          end
        end
      end

      messages.join("\n\n")
    end

    def cover_message_parts
      parts = messages
      parts << orphaned_message unless other_comments.empty?
      parts
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
        position_key = position.is_a?(Integer) ? :line : :range
        position = JSON.parse(position) unless position.is_a?(Integer)
        {
          :message => comment,
          position_key => position
        }
      end
    end
  end
end
