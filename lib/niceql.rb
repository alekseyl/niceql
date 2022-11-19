# frozen_string_literal: true

require "niceql/version"
require "securerandom"
require "forwardable"

module Niceql
  module StringColorize
    class << self
      def colorize_keyword(str)
        # yellow ANSI color
        "\e[0;33;49m#{str}\e[0m"
      end

      def colorize_str(str)
        # cyan ANSI color
        "\e[0;36;49m#{str}\e[0m"
      end

      def colorize_err(err)
        # red ANSI color
        "\e[0;31;49m#{err}\e[0m"
      end

      def colorize_comment(comment)
        # bright black bold ANSI color
        "\e[0;90;1;49m#{comment}\e[0m"
      end
    end
  end

  module Prettifier
    # ?= -- should be present but without being added to MatchData
    AFTER_KEYWORD_SPACE = '(?=\s{1})'
    JOIN_KEYWORDS = '(RIGHT\s+|LEFT\s+){0,1}(INNER\s+|OUTER\s+){0,1}JOIN(\s+LATERAL){0,1}'
    INLINE_KEYWORDS = "WITH|ASC|COALESCE|AS|WHEN|THEN|ELSE|END|AND|UNION|ALL|ON|DISTINCT|"\
      "INTERSECT|EXCEPT|EXISTS|NOT|COUNT|ROUND|CAST|IN"
    NEW_LINE_KEYWORDS = "SELECT|FROM|WHERE|CASE|ORDER BY|LIMIT|GROUP BY|HAVING|OFFSET|UPDATE|SET|#{JOIN_KEYWORDS}"

    POSSIBLE_INLINER = /(ORDER BY|CASE)/
    KEYWORDS = "(#{NEW_LINE_KEYWORDS}|#{INLINE_KEYWORDS})#{AFTER_KEYWORD_SPACE}"
    # ?: -- will not match partial enclosed by (..)
    MULTILINE_INDENTABLE_LITERAL = /(?:'[^']+'\s*\n+\s*)+(?:'[^']+')+/
    # STRINGS matched both kind of strings the multiline solid
    # and single quoted multiline strings with \s*\n+\s* separation
    STRINGS = /("[^"]+")|((?:'[^']+'\s*\n+\s*)*(?:'[^']+')+)/
    BRACKETS = '[\(\)]'
    # will match all /* single line and multiline comments */ and -- based comments
    # the last will be matched as single block whenever comment lines followed each other.
    # For instance:
    # SELECT * -- comment 1
    # -- comment 2
    # all comments will be matched as a single block
    SQL_COMMENTS = %r{(\s*?--[^\n]+\n*)+|(\s*?/\*[^/\*]*\*/\s*)}m
    COMMENT_CONTENT = /[\S]+[\s\S]*[\S]+/
    NAMED_DOLLAR_QUOTED_STRINGS_REGEX = /[^\$](\$[^\$]+\$)[^\$]/
    DOLLAR_QUOTED_STRINGS = /(\$\$.*\$\$)/

    class << self
      def config
        Niceql.config
      end

      def prettify_err(err, original_sql_query = nil)
        prettify_pg_err(err.to_s, original_sql_query)
      end

      # Postgres error output:
      # ERROR:  VALUES in FROM must have an alias
      # LINE 2: FROM ( VALUES(1), (2) );
      #              ^
      # HINT:  For example, FROM (VALUES ...) [AS] foo.

      # May go without HINT or DETAIL:
      # ERROR:  column "usr" does not exist
      # LINE 1: SELECT usr FROM users ORDER BY 1
      #                ^

      # ActiveRecord::StatementInvalid will add original SQL query to the bottom like this:
      # ActiveRecord::StatementInvalid: PG::UndefinedColumn: ERROR:  column "usr" does not exist
      # LINE 1: SELECT usr FROM users ORDER BY 1
      #                ^
      # : SELECT usr FROM users ORDER BY 1

      # prettify_pg_err parses ActiveRecord::StatementInvalid string,
      # but you may use it without ActiveRecord either way:
      # prettify_pg_err( err + "\n" + sql ) OR prettify_pg_err( err, sql )
      # don't mess with original sql query, or prettify_pg_err will deliver incorrect results
      def prettify_pg_err(err, original_sql_query = nil)
        return err if err[/LINE \d+/].nil?

        # LINE 2: ... -> err_line_num = 2
        err_line_num = err.match(/LINE (\d+):/)[1].to_i
        # LINE 1: SELECT usr FROM users ORDER BY 1
        err_address_line = err.lines[1]

        sql_start_line_num = 3 if err.lines.length <= 3
        # error not always contains HINT
        sql_start_line_num ||= err.lines[3][/(HINT|DETAIL)/] ? 4 : 3
        sql_body_lines = if sql_start_line_num < err.lines.length
          err.lines[sql_start_line_num..-1]
        else
          original_sql_query&.lines
        end

        # this means original query is missing so it's nothing to prettify
        return err unless sql_body_lines

        # this is an SQL line with an error.
        # we need err_line to properly align the caret in the caret line
        # and to apply a full red colorizing schema on an SQL line with error
        err_line = sql_body_lines[err_line_num - 1]

        # colorizing keywords, strings and error line
        err_body = sql_body_lines.map do |ln|
          ln == err_line ? StringColorize.colorize_err(ln) : colorize_err_line(ln)
        end

        err_caret_line = extract_err_caret_line(err_address_line, err_line, sql_body_lines, err)
        err_body.insert(err_line_num, StringColorize.colorize_err(err_caret_line))

        err.lines[0..sql_start_line_num - 1].join + err_body.join
      end

      def prettify_sql(sql, colorize = true)
        QueryNormalizer.new(sql, colorize).prettified_sql
      end

      def prettify_multiple(sql_multi, colorize = true)
        sql_multi.split(/(?>#{SQL_COMMENTS})|(\;)/).each_with_object([""]) do |pattern, queries|
          queries[-1] += pattern
          queries << "" if pattern == ";"
        end.map! do |sql|
          # we were splitting by comments and ';', so if next sql start with comment we've got a misplaced \n\n
          sql.match?(/\A\s+\z/) ? nil : prettify_sql(sql, colorize)
        end.compact.join("\n")
      end

      private

      def colorize_err_line(line)
        line.gsub(/#{KEYWORDS}/) { |keyword| StringColorize.colorize_keyword(keyword) }
          .gsub(STRINGS) { |str| StringColorize.colorize_str(str) }
      end

      def extract_err_caret_line(err_address_line, err_line, sql_body, err)
        # LINE could be quoted ( both sides and sometimes only from one ):
        # "LINE 1: ...t_id\" = $13 AND \"products\".\"carrier_id\" = $14 AND \"product_t...\n",
        err_quote = (err_address_line.match(/\.\.\.(.+)\.\.\./) || err_address_line.match(/\.\.\.(.+)/))&.send(:[], 1)

        # line[2] is original err caret line i.e.: '      ^'
        # err_address_line[/LINE \d+:/].length+1..-1 - is a position from error quote begin
        err_caret_line = err.lines[2][err_address_line[/LINE \d+:/].length + 1..-1]

        # when err line is too long postgres quotes it in double '...'
        # so we need to reposition caret against original line
        if err_quote
          err_quote_caret_offset = err_caret_line.length - err_address_line.index("...").to_i + 3
          err_caret_line = " " * (err_line.index(err_quote) + err_quote_caret_offset) + "^\n"
        end

        # older versions of ActiveRecord were adding ': ' before an original query :(
        err_caret_line.prepend("  ") if sql_body[0].start_with?(": ")
        # if mistake is on last string than err_line.last != \n then we need to prepend \n to caret line
        err_caret_line.prepend("\n") unless err_line[-1] == "\n"
        err_caret_line
      end
    end

    # The normalizing and formatting logic:
    # 1. Split the original query onto the query part + literals + comments
    #   a. find all potential dollar-signed separators
    #   b. prepare full literal extractor regex
    # 2. Find and separate all literals and comments into mutable/format-able types
    #    and immutable  ( see the typing and formatting rules below )
    # 3. Replace all literals and comments with uniq ids on the original query to get the parametrized query
    # 4. Format parametrized query alongside with mutable/format-able comments and literals
    #   a. clear space characters: replace all \s+ to \s, remove all "\n" e.t.c
    #   b. split in lines -> indent -> colorize
    # 5. Restore literals and comments with their values
    class QueryNormalizer
      extend Forwardable
      def_delegator :Niceql, :config

      # Literals content should not be indented, only string parts separated by new lines can be indented
      # indentable_string:
      # UPDATE docs SET body = 'First line'
      # 'Second line'
      # 'Third line', ...
      #
      # SQL standard allow such multiline separation.

      # newline_end_comments:
      # SELECT * -- get all column
      # SELECT * /* get all column */
      #
      # SELECT * -- get all column
      # -- we need all columns for this request
      # SELECT * /* get all column
      # we need all columns for this request */
      #
      # rare case newline_start_comments:
      # SELECT *
      # /* get all column
      # we need all columns for this request */ FROM table
      #
      # newline_wrapped_comments:
      # SELECT *
      # /* get all column
      # we need all columns for this request */
      # FROM table
      #
      # SELECT *
      # -- get all column
      # -- we need all columns for this request
      # FROM ...
      # Potentially we could prettify different type of comments and strings a little bit differently,
      # but right now there is no difference between the
      # newline_wrapped_comment, newline_start_comment, newline_end_comment, they all will be wrapped in newlines
      COMMENT_AND_LITERAL_TYPES = [:immutable_string, :indentable_string, :inline_comment, :newline_wrapped_comment,
                                   :newline_start_comment, :newline_end_comment]

      attr_reader :parametrized_sql, :initial_sql, :string_regex, :literals_and_comments_types, :colorize

      def initialize(sql, colorize)
        @initial_sql = sql
        @colorize = colorize
        @parametrized_sql = ""
        @guids_to_content = {}
        @literals_and_comments_types = {}
        @counter = Hash.new(0)

        init_strings_regex
        prepare_parametrized_sql
        prettify_parametrized_sql
      end

      def prettified_sql
        @parametrized_sql % @guids_to_content.transform_keys(&:to_sym)
      end

      private

      def prettify_parametrized_sql
        indent = 0
        brackets = []
        first_keyword = true

        parametrized_sql.gsub!(query_split_regex) do |matched_part|
          if inline_piece?(matched_part)
            first_keyword = false
            next matched_part
          end
          post_match_str = Regexp.last_match.post_match

          if ["SELECT", "UPDATE", "INSERT"].include?(matched_part)
            indent_block = !config.open_bracket_is_newliner || brackets.last.nil? || brackets.last[:nested]
            indent += config.indentation_base if indent_block
            brackets.last[:nested] = true if brackets.last
            add_new_line = !first_keyword
          elsif matched_part == "("
            next_closing_bracket = post_match_str.index(")")
            # check if brackets contains SELECT statement
            add_new_line = !!post_match_str[0..next_closing_bracket][/SELECT/] && config.open_bracket_is_newliner
            brackets << { nested: add_new_line }
          elsif matched_part == ")"
            # this also covers case when right bracket is used without corresponding left one
            add_new_line = brackets.last.nil? || brackets.last[:nested]
            indent -= (brackets.last.nil? && 2 || brackets.last[:nested] && 1 || 0) * config.indentation_base
            indent = 0 if indent < 0
            brackets.pop
          elsif matched_part[POSSIBLE_INLINER]
            # in postgres ORDER BY can be used in aggregation function this will keep it
            # inline with its agg function
            add_new_line = brackets.last.nil? || brackets.last[:nested]
          else
            # since we are matching KEYWORD without space on the end
            # IN will be present in JOIN, DISTINCT e.t.c, so we need to exclude it explicitly
            add_new_line = matched_part.match?(/(#{NEW_LINE_KEYWORDS})/)
          end

          # do not indent first keyword in query, and indent everytime we started new line
          add_indent_to_keyword = !first_keyword && add_new_line

          if literals_and_comments_types[matched_part]
            # this is a case when comment followed by ordinary SQL part not by any keyword
            # this means that it will not be gsubed and no indent will be added before this part, while needed
            last_comment_followed_by_keyword = post_match_str.match?(/\A\}\s{0,1}(?:#{KEYWORDS})/)
            indent_parametrized_part(matched_part, indent, !last_comment_followed_by_keyword, !first_keyword)
            matched_part
          else
            first_keyword = false
            indented_sql = (add_indent_to_keyword ? indent_multiline(matched_part, indent) : matched_part)
            add_new_line ? "\n" + indented_sql : indented_sql
          end
        end

        parametrized_sql.gsub!(" \n", "\n") # moved keywords could keep space before it, we can crop it anyway

        clear_extra_newline_after_comments

        colorize_query if colorize
      end

      def add_string_or_comment(string_or_comment)
        # when we splitting original SQL, it could and could not end with literal/comment
        # hence we could try to add nil...
        return if string_or_comment.nil?

        type = get_placeholder_type(string_or_comment)
        # will be formatted to comment_1_guid
        typed_id = new_placeholder_name(type)
        @guids_to_content[typed_id] = string_or_comment
        @counter[type] += 1
        @literals_and_comments_types[typed_id] = type
        "%{#{typed_id}}"
      end

      def literal_and_comments_placeholders_regex
        /(#{@literals_and_comments_types.keys.join("|")})/
      end

      def inline_piece?(comment_or_string)
        [:immutable_string, :inline_comment].include?(literals_and_comments_types[comment_or_string])
      end

      def prepare_parametrized_sql
        @parametrized_sql = @initial_sql.split(/#{SQL_COMMENTS}|#{string_regex}/)
          .each_slice(2).map do |sql_part, comment_or_string|
          # remove additional formatting for sql_parts and replace comment and strings with a guids
          [sql_part.gsub(/[\s]+/, " "), add_string_or_comment(comment_or_string)]
        end.flatten.compact.join("")
      end

      def query_split_regex(with_brackets = true)
        if with_brackets
          /(#{KEYWORDS}|#{BRACKETS}|#{literal_and_comments_placeholders_regex})/
        else
          /(#{KEYWORDS}|#{literal_and_comments_placeholders_regex})/
        end
      end

      # when comment ending with newline followed by a keyword we should remove double newlines
      def clear_extra_newline_after_comments
        newlined_comments = @literals_and_comments_types.select { |k,| new_line_ending_comment?(k) }
        return if newlined_comments.empty?

        parametrized_sql.gsub!(/(#{newlined_comments.keys.join("}\n|")}}\n)/, &:chop)
      end

      def colorize_query
        parametrized_sql.gsub!(query_split_regex(false)) do |matched_part|
          if literals_and_comments_types[matched_part]
            colorize_comment_or_literal(matched_part)
            matched_part
          else
            StringColorize.colorize_keyword(matched_part)
          end
        end
      end

      def indent_parametrized_part(matched_typed_id, indent, indent_after_comment, start_with_newline = true)
        case @literals_and_comments_types[matched_typed_id]
        # technically we will not get here, since this types of literals/comments are not indentable
        when :inline_comment, :immutable_string
        when :indentable_string
          lines = @guids_to_content[matched_typed_id].lines
          @guids_to_content[matched_typed_id] = lines[0] +
            lines[1..-1].map! { |ln| indent_multiline(ln[/'[^']+'/], indent) }.join("\n")
        else
          content = @guids_to_content[matched_typed_id][COMMENT_CONTENT]
          @guids_to_content[matched_typed_id] = (start_with_newline ? "\n" : "") +
            "#{indent_multiline(content, indent)}\n" +
            (indent_after_comment ? indent_multiline("", indent) : "")
        end
      end

      def colorize_comment_or_literal(matched_typed_id)
        @guids_to_content[matched_typed_id] = if comment?(@literals_and_comments_types[matched_typed_id])
          StringColorize.colorize_comment(@guids_to_content[matched_typed_id])
        else
          StringColorize.colorize_str(@guids_to_content[matched_typed_id])
        end
      end

      def get_placeholder_type(comment_or_string)
        if SQL_COMMENTS.match?(comment_or_string)
          get_comment_type(comment_or_string)
        else
          get_string_type(comment_or_string)
        end
      end

      def get_comment_type(comment)
        case comment
        when /\s*\n+\s*.+\s*\n+\s*/ then :newline_wrapped_comment
        when /\s*\n+\s*.+/ then :newline_start_comment
        when /.+\s*\n+\s*/ then :newline_end_comment
        else :inline_comment
        end
      end

      def get_string_type(string)
        MULTILINE_INDENTABLE_LITERAL.match?(string) ? :indentable_string : :immutable_string
      end

      def new_placeholder_name(placeholder_type)
        "#{placeholder_type}_#{@counter[placeholder_type]}_#{SecureRandom.uuid}"
      end

      def get_sql_named_strs(sql)
        freq = Hash.new(0)
        sql.scan(NAMED_DOLLAR_QUOTED_STRINGS_REGEX).select do |str|
          freq[str] += 1
          freq[str] == 2
        end
          .flatten
          .map { |str| str.gsub!("$", '\$') }
      end

      def init_strings_regex
        # /($STR$.+$STR$|$$[^$]$$|'[^']'|"[^"]")/
        strs = get_sql_named_strs(initial_sql).map { |dq_str| "#{dq_str}.+#{dq_str}" }
        strs = ["(#{strs.join("|")})"] if strs != []
        @string_regex ||= /#{[*strs, DOLLAR_QUOTED_STRINGS, STRINGS].join("|")}/m
      end

      def comment?(piece_type)
        !literal?(piece_type)
      end

      def literal?(piece_type)
        [:indentable_string, :immutable_string].include?(piece_type)
      end

      def new_line_ending_comment?(comment_or_literal)
        [:newline_wrapped_comment, :newline_end_comment, :newline_start_comment]
          .include?(@literals_and_comments_types[comment_or_literal])
      end

      def indent_multiline(keyword, indent)
        if keyword.match?(/.\s*\n\s*./)
          keyword.lines.map! { |ln| " " * indent + ln }.join("")
        else
          " " * indent + keyword
        end
      end
    end
  end

  class NiceQLConfig
    attr_accessor :indentation_base, :open_bracket_is_newliner

    def initialize
      self.indentation_base = 2
      self.open_bracket_is_newliner = false
    end
  end

  class << self
    def configure
      yield(config)
    end

    def config
      @config ||= NiceQLConfig.new
    end
  end
end
