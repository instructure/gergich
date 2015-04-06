require "sqlite3"
require "fileutils"

module Gergich
  class Commit
    class << self
      def info
        @info ||= begin
          output = `git log -1 HEAD`
          /\Acommit (?<revision_id>[0-9a-f]+).*^\s*Change-Id: (?<change_id>\w+)/m =~ output
          {revision_id: revision_id, change_id: change_id}
        end
      end

      def revision_id
        info[:revision_id]
      end

      def change_id
        info[:change_id]
      end
    end
  end

  class Review
    attr_reader :commit, :draft
    def initialize(commit = Commit, draft = Draft.new)
      @commit = commit
      @draft = draft
    end

    # Public: publish all draft comments. Cover message is auto generated
    def publish!
      return if review_info[:comments].size == 0
      require "pp"
      pp generate_payload
      # TODO zomg
    end

    def review_info
      @review_info ||= draft.info
    end

    def generate_cover_message
      if review_info[:counts_by_severity]["error"] > 0
        "Found some stuff that needs to be fixed, see inline comments"
      elsif review_info[:counts_by_severity]["warn"] > 0
        "Found some stuff that would be nice to fix, see inline comments"
      else
        "Looks good, just some notes inline"
      end
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
        message: generate_cover_message,
        labels: generate_label,
        comments: review_info[:comments]
      }.to_json
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
    #            the comment (e.g. "[ERROR] message here"), and most
    #            severe comment will be used to determine the overall
    #            Code-Review score (0, -1, or -2 respectively)
    def add_comment(path, position, message, severity)
      raise "invalid path `#{path}`" unless path && File.exist?(path)
      raise "invalid position `#{position}`" unless position.is_a?(Fixnum) && position >= 0 ||
                                                    position.is_a?(Hash) && position.keys.sort == %w[end_character end_line start_character start_line] && position.values.all? { |v| v.is_a?(Fixnum) && v >= 0 }
      raise "invalid severity `#{severity}`" unless SEVERITY_MAP.key?(severity)
      raise "no message specified" unless message.is_a?(String) && message.size > 0

      db.execute "INSERT INTO comments (path, position, message, severity) VALUES (?, ?, ?, ?)",
        [path, position, message, severity]
    end

    def info
      @info ||= begin
        score = 0
        counts_by_severity = Hash.new(0)
        files_hash = Hash.new { |hash, path| hash[path] = FileReview.new(path) }

        db.execute("SELECT path, position, message, severity FROM comments").each do |row|
          files_hash[row["path"]].add_comment(row["position"], row["message"], row["severity"])
          score = [score, SEVERITY_MAP[row["severity"]]].min
          counts_by_severity[row["severity"]] += 1
        end

        {
          comments: Hash[files_hash.map { |key, file| [key, file.to_a] }],
          score: score,
          counts_by_severity: counts_by_severity
        }
      end
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
