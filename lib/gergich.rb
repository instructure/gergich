require "sqlite3"
require "fileutils"

require_relative "cover_messages"

module Gergich
  class Commit
    class << self
      def info
        @info ||= begin
          output = git("log -1 HEAD")
          /\Acommit (?<revision_id>[0-9a-f]+).*^\s*Change-Id: (?<change_id>\w+)/m =~ output
          {revision_id: revision_id, change_id: change_id}
        end
      end

      def files
        @files ||= git("diff-tree --no-commit-id --name-only -r HEAD").split
      end

      def revision_id
        info[:revision_id]
      end

      def change_id
        info[:change_id]
      end

      def git(args)
        Dir.chdir(git_dir) do
          `git #{args}`
        end
      end

      def git_dir
        ENV["GERGICH_GIT_PATH"] || "."
      end
    end
  end

  class Review
    attr_reader :commit, :draft, :api
    def initialize(commit = Commit, draft = Draft.new)
      @commit = commit
      @draft = draft
      @api = API.new
    end

    # Public: publish all draft comments. Cover message is auto generated
    def publish!
      # only publish if we have something to say or if our last score was negative
      return unless review_info[:total_comments] > 0 || previous_score_negative?

      # TODO: rather than just bailing, fetch the comments and only post
      # ones that don't exist (if any)
      return if already_commented?

      api.post(generate_url, generate_payload)

      # because why not
      if rand < 0.01
        api.put("/accounts/self/name", {name: whats_his_face}.to_json)
      end

      review_info
    end

    def previous_score_negative?
      last_message = my_messages
        .sort_by { |message| message["date"] }
        .last

      text = last_message && last_message["message"] || ""
      CoverMessages.previous_score_minus(text)
    end

    def already_commented?
      gerrit_info = api.get("/changes/?q=#{commit.change_id}&o=ALL_REVISIONS")[0]
      revision_number = gerrit_info["revisions"][commit.revision_id]["_number"]
      my_messages.any? { |message| message["_revision_number"] == revision_number }
    end

    def my_messages
      @messages ||= api.get("/changes/#{commit.change_id}/detail")["messages"]
        .select { |message| message["author"] && message["author"]["username"] == "gergich" }
    end

    def whats_his_face
      "#{%w[Garry Larry Terry Jerry].sample} Gergich (Bot)"
    end

    def review_info
      @review_info ||= draft.info
    end

    def generate_label
      {
        "Code-Review" => review_info[:score]
      }
    end

    def generate_url
      "/changes/#{commit.change_id}/revisions/#{commit.revision_id}/review"
    end

    def generate_payload
      {
        message: review_info[:cover_message],
        labels: generate_label,
        comments: review_info[:comments],
        strict_labels: false # we don't want the post to fail if another patchset was created in the interim
      }.to_json
    end
  end

  class API
    attr_reader :http, :cookie, :csrf_token

    def initialize
      raise "No GERGICH_KEY set" if !ENV['GERGICH_KEY']
    end

    def get(url)
      curl(url)
    end

    def post(url, body)
      curl(url, "-H \"Content-Type: application/json\" --data-binary #{bash_escape(body)}")
    end

    def put(url, body)
      curl(url, "-X PUT -H \"Content-Type: application/json\" --data-binary #{bash_escape(body)}")
    end

    private

    def bash_escape(string)
      # wrap it all in single quotes, except single quotes where we break
      # out and escape them
      "'" + string.gsub("'",  "'\\\\''") + "'"
    end

    # there's no built-in ruby http digest auth, and to make this portable
    # we can't relay on HTTParty or others being present. but curl is
    # everywhere :)
    def curl(path, extras = nil)
      ret = `curl --digest -u gergich:#{ENV["GERGICH_KEY"]} #{extras} "https://gerrit.instructure.com/a#{path}" 2>/dev/null`
      json = if ret.sub!(/\A\)\]\}'\n/, '') && ret =~ /\A("|\[|\{)/
        JSON.parse("[#{ret}]")[0] rescue nil
      end
      json || raise("Non-JSON response: #{ret}")
    end
  end

  class Draft
    SEVERITY_MAP = {
      "info" => 0,
      "warn" => -1,
      "error" => -2
    }

    attr_reader :db, :commit

    def initialize(commit = Commit)
      @commit = commit
    end

    def db_file
      @db_file ||= File.expand_path("/tmp/gergich-#{commit.revision_id}.sqlite3")
    end

    def db
      @db ||= begin
        db_exists = File.exist?(db_file)
        db = SQLite3::Database.new(db_file)
        db.results_as_hash = true
        create_db_schema! if !db_exists
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
    end

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
      raise "invalid position `#{position}`" unless position.is_a?(Fixnum) && position >= 0 ||
                                                    position.is_a?(Hash) && position.keys.sort == %w[end_character end_line start_character start_line] && position.values.all? { |v| v.is_a?(Fixnum) && v >= 0 }
      raise "invalid severity `#{severity}`" unless SEVERITY_MAP.key?(severity)
      raise "no message specified" unless message.is_a?(String) && message.size > 0

      db.execute "INSERT INTO comments (path, position, message, severity) VALUES (?, ?, ?, ?)",
        [path, position, message, severity]
    end

    def info
      @info ||= begin
        changed_files = commit.files

        score = 0
        total_comments = 0
        commit_files_hash = Hash.new { |hash, path| hash[path] = FileReview.new(path) }
        other_files_hash = Hash.new { |hash, path| hash[path] = FileReview.new(path) }

        db.execute("SELECT path, position, message, severity FROM comments").each do |row|
          total_comments += 1
          collection = changed_files.include?(row['path']) ? commit_files_hash : other_files_hash
          collection[row["path"]].add_comment(row["position"], row["message"], row["severity"])
          score = [score, SEVERITY_MAP[row["severity"]]].min
        end

        cover_message = infer_cover_message(score, total_comments, other_files_hash)

        {
          comments: Hash[commit_files_hash.map { |key, file| [key, file.to_a] }],
          cover_message: cover_message,
          score: score,
          total_comments: total_comments # inline comments, plus ones in cover message
        }
      end
    end

    def infer_cover_message(score, total_comments, orphaned_files_hash)
      cover_message = if score == -2
                        CoverMessages.minus_two.sample
                      elsif score == -1
                        CoverMessages.minus_one.sample
                      elsif total_comments == 1
                        CoverMessages.one_comment.sample
                      elsif total_comments > 1
                        CoverMessages.multiple_comments.sample
                      else
                        CoverMessages.now_fixed.sample
                      end

      if orphaned_files_hash.size > 0
        cover_message << "\n\n" <<
          "NOTE: I couldn't create inline comments for everything. " <<
          "Although this isn't technically part of your commit, you " <<
          "should still check it out (i.e. side effects or auto-" <<
          "generated from stuff you *did* change):"

        orphaned_files_hash.each do |path, file|
          file.comments.each do |position, comments|
            comments.each do |comment|
              line = position.is_a?(Fixnum) ? position : position["start_line"]
              cover_message << "\n\n#{path}:#{line}: #{comment}"
            end
          end
        end
      end

      cover_message
    end
  end

  class FileReview
    attr_accessor :path, :comments
    def initialize(path)
      self.path = path
      self.comments = Hash.new { |hash, position| hash[position] = [] }
    end

    def add_comment(position, message, severity)
      position = position.to_i if position =~ /\A\d+\z/
      comments[position] << "[#{severity.upcase}] #{message}"
    end

    def to_a
      comments.map do |position, position_comments|
        comment = position_comments.join("\n\n")
        position_key = position.is_a?(Fixnum) ? :line : :range
        {
          :message => comment,
          position_key => position
        }
      end
    end
  end
end
