require "niceql/version"

module Niceql

  module StringColorize
    def self.colorize_verb( str)
      #yellow ANSI color
      "\e[0;33;49m#{str}\e[0m"
    end
    def self.colorize_str(str)
      #cyan ANSI color
      "\e[0;36;49m#{str}\e[0m"
    end
    def self.colorize_err(err)
      #red ANSI color
      "\e[0;31;49m#{err}\e[0m"
    end
  end

  module ArExtentions
    def exec_niceql
      connection.execute( to_niceql )
    end

    def to_niceql
      Prettifier.prettify_sql(to_sql, false)
    end

    def niceql( colorize = true )
      puts Prettifier.prettify_sql( to_sql, colorize )
    end

  end

  module Prettifier
    INLINE_VERBS = %w(WITH ASC (IN\s) COALESCE AS WHEN THEN ELSE END AND UNION ALL ON DISTINCT INTERSECT EXCEPT EXISTS NOT COUNT ROUND CAST).join('| ')
    NEW_LINE_VERBS = 'SELECT|FROM|WHERE|CASE|ORDER BY|LIMIT|GROUP BY|(RIGHT |LEFT )*(INNER |OUTER )*JOIN( LATERAL)*|HAVING|OFFSET|UPDATE'
    POSSIBLE_INLINER = /(ORDER BY|CASE)/
    VERBS = "#{NEW_LINE_VERBS}|#{INLINE_VERBS}"
    STRINGS = /("[^"]+")|('[^']+')/
    BRACKETS = '[\(\)]'
    SQL_COMMENTS = /(\s*?--.+\s*)|(\s*?\/\*[^\/\*]*\*\/\s*)/
    # only newlined comments will be matched
    SQL_COMMENTS_CLEARED = /(\s*?--.+\s{1})|(\s*$\s*\/\*[^\/\*]*\*\/\s{1})/
    COMMENT_CONTENT = /[\S]+[\s\S]*[\S]+/

    class << self
      def config
        Niceql.config
      end

      def prettify_err(err, original_sql_query = nil)
        prettify_pg_err( err.to_s, original_sql_query )
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
      #: SELECT usr FROM users ORDER BY 1

      # prettify_pg_err parses ActiveRecord::StatementInvalid string,
      # but you may use it without ActiveRecord either way:
      # prettify_pg_err( err + "\n" + sql ) OR prettify_pg_err( err, sql )
      # don't mess with original sql query, or prettify_pg_err will deliver incorrect results
      def prettify_pg_err(err, original_sql_query = nil)
        return err if err[/LINE \d+/].nil?
        err_line_num = err[/LINE \d+/][5..-1].to_i
        # LINE 1: SELECT usr FROM users ORDER BY 1
        err_address_line = err.lines[1]

        start_sql_line = 3 if err.lines.length <= 3
        # error not always contains HINT
        start_sql_line ||= err.lines[3][/(HINT|DETAIL)/] ? 4 : 3
        sql_body = start_sql_line < err.lines.length ? err.lines[start_sql_line..-1] : original_sql_query&.lines

        # this means original query is missing so it's nothing to prettify
        return err unless sql_body

        # err line will be painted in red completely, so we just remembering it and use
        # to replace after painting the verbs
        err_line = sql_body[err_line_num - 1]


        #colorizing verbs and strings
        colorized_sql_body = sql_body.join.gsub(/#{VERBS}/ ) { |verb| StringColorize.colorize_verb(verb) }
          .gsub(STRINGS){ |str| StringColorize.colorize_str(str) }

        #reassemling error message
        err_body = colorized_sql_body.lines
        # replacing colorized line contained error and adding caret line
        err_body[err_line_num - 1]= StringColorize.colorize_err( err_line )

        err_caret_line = extract_err_caret_line( err_address_line, err_line, sql_body, err )
        err_body.insert( err_line_num, StringColorize.colorize_err( err_caret_line ) )

        err.lines[0..start_sql_line-1].join + err_body.join
      end

      def prettify_sql( sql, colorize = true )
        indent = 0
        parentness = []

        sql = sql.split( SQL_COMMENTS ).each_slice(2).map{ | sql_part, comment |
          # remove additional formatting for sql_parts but leave comment intact
          [sql_part.gsub(/[\s]+/, ' '),
           # comment.match?(/\A\s*$/) - SQL_COMMENTS gets all comment content + all whitespaced chars around
           # so this sql_part.length == 0 || comment.match?(/\A\s*$/) checks does the comment starts from new line
           comment && ( sql_part.length == 0 || comment.match?(/\A\s*$/) ? "\n#{comment[COMMENT_CONTENT]}\n" : comment[COMMENT_CONTENT] ) ]
        }.flatten.join(' ')

        sql.gsub!(/ \n/, "\n")

        sql.gsub!(STRINGS){ |str| StringColorize.colorize_str(str) } if colorize

        first_verb  = true
        prev_was_comment = false

        sql.gsub!( /(#{VERBS}|#{BRACKETS}|#{SQL_COMMENTS_CLEARED})/) do |verb|
          if 'SELECT' == verb
            indent += config.indentation_base if !config.open_bracket_is_newliner || parentness.last.nil? || parentness.last[:nested]
            parentness.last[:nested] = true if parentness.last
            add_new_line = !first_verb
          elsif verb == '('
            next_closing_bracket = Regexp.last_match.post_match.index(')')
            # check if brackets contains SELECT statement
            add_new_line = !!Regexp.last_match.post_match[0..next_closing_bracket][/SELECT/] && config.open_bracket_is_newliner
            parentness << { nested: add_new_line }
          elsif verb == ')'
            # this also covers case when right bracket is used without corresponding left one
            add_new_line = parentness.last.nil? || parentness.last[:nested]
            indent -= ( parentness.last.nil? ? 2 * config.indentation_base : (parentness.last[:nested] ? config.indentation_base : 0) )
            indent = 0 if indent < 0
            parentness.pop
          elsif verb[POSSIBLE_INLINER]
            # in postgres ORDER BY can be used in aggregation function this will keep it
            # inline with its agg function
            add_new_line = parentness.last.nil? || parentness.last[:nested]
          else
            add_new_line = verb[/(#{INLINE_VERBS})/].nil?
          end

          # !add_new_line && previous_was_comment means we had newlined comment, and now even
          # if verb is inline verb we will need to add new line with indentation BUT all
          # inliners match with a space before so we need to strip it
          verb.lstrip! if !add_new_line && prev_was_comment

          add_new_line = prev_was_comment unless add_new_line
          add_indent = !first_verb && add_new_line

          if verb[SQL_COMMENTS_CLEARED]
            verb = verb[COMMENT_CONTENT]
            prev_was_comment = true
          else
            first_verb = false
            prev_was_comment = false
          end

          verb = StringColorize.colorize_verb(verb) if !%w[( )].include?(verb) && colorize

          subs = ( add_indent ? indent_multiline(verb, indent) : verb)
          !first_verb && add_new_line ? "\n" + subs : subs
        end

        # clear all spaces before newlines, and all whitespaces before strings endings
        sql.tap{ |slf| slf.gsub!( /\s+\n/, "\n" ) }.tap{ |slf| slf.gsub!(/\s+\z/, '') }
      end

      def prettify_multiple( sql_multi, colorize = true )
        sql_multi.split( /(?>#{SQL_COMMENTS})|(\;)/ ).inject(['']) { |queries, pattern|
          queries.last << pattern
          queries << '' if pattern == ';'
          queries
        }.map!{ |sql|
          # we were splitting by comments and ;, so if next sql start with comment we've got a misplaced \n\n
          sql.match?(/\A\s+\z/) ? nil : prettify_sql( sql, colorize )
        }.compact.join("\n\n")
      end

      private_class_method
      def indent_multiline( verb, indent )
        if verb.match?(/.\s*\n\s*./)
          verb.lines.map!{|ln| ln.prepend(' ' * indent)}.join("\n")
        else
          verb.prepend(' ' * indent)
        end
      end

      def extract_err_caret_line( err_address_line, err_line, sql_body, err )
        # LINE could be quoted ( both sides and sometimes only from one ):
        # "LINE 1: ...t_id\" = $13 AND \"products\".\"carrier_id\" = $14 AND \"product_t...\n",
        err_quote = (err_address_line.match(/\.\.\.(.+)\.\.\./) || err_address_line.match(/\.\.\.(.+)/) ).try(:[], 1)

        # line[2] is original err caret line i.e.: '      ^'
        # err_address_line[/LINE \d+:/].length+1..-1 - is a position from error quote begin
        err_caret_line = err.lines[2][err_address_line[/LINE \d+:/].length+1..-1]

        # when err line is too long postgres quotes it in double '...'
        # so we need to reposition caret against original line
        if err_quote
          err_quote_caret_offset = err_caret_line.length - err_address_line.index( '...' ).to_i + 3
          err_caret_line =  ' ' * ( err_line.index( err_quote ) + err_quote_caret_offset ) + "^\n"
        end

        # older versions of ActiveRecord were adding ': ' before an original query :(
        err_caret_line.prepend('  ') if sql_body[0].start_with?(': ')
        # if mistake is on last string than err_line.last != \n then we need to prepend \n to caret line
        err_caret_line.prepend("\n") unless err_line[-1] == "\n"
        err_caret_line
      end
    end
  end

  module PostgresAdapterNiceQL
    def exec_query(sql, name = "SQL", binds = [], prepare: false)
      # replacing sql with prettified sql, thats all
      super( Prettifier.prettify_sql(sql, false), name, binds, prepare: prepare )
    end
  end

  module AbstractAdapterLogPrettifier
    def log( sql, *args, &block )
      # \n need to be placed because AR log will start with action description + time info.
      # rescue sql - just to be sure Prettifier wouldn't break production
      formatted_sql = "\n" + Prettifier.prettify_sql(sql) rescue sql
      super( formatted_sql, *args, &block )
    end
  end

  module ErrorExt
    def to_s
      # older rails version do not provide sql as a standalone query, instead they
      # deliver joined message
      Niceql.config.prettify_pg_errors ? Prettifier.prettify_err(super, try(:sql) ) : super
    end
  end

  class NiceQLConfig
    def ar_using_pg_adapter?
      return false unless defined?(::ActiveRecord::Base)

      adapter = ActiveRecord::Base.try(:connection_db_config).try(:adapter) ||
        ActiveRecord::Base.try(:connection_config)&.with_indifferent_access&.dig(:adapter)

      adapter == 'postgresql'
    end

    attr_accessor :pg_adapter_with_nicesql,
                  :indentation_base,
                  :open_bracket_is_newliner,
                  :prettify_active_record_log_output,
                  :prettify_pg_errors


    def initialize
      self.pg_adapter_with_nicesql = false
      self.indentation_base = 2
      self.open_bracket_is_newliner = false
      self.prettify_active_record_log_output = false
      self.prettify_pg_errors = ar_using_pg_adapter?
    end
  end

  def self.configure
    yield( config )

    return unless defined? ::ActiveRecord::Base

    ::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.include(PostgresAdapterNiceQL) if config.pg_adapter_with_nicesql

    ::ActiveRecord::ConnectionAdapters::AbstractAdapter.prepend( AbstractAdapterLogPrettifier ) if config.prettify_active_record_log_output

    ::ActiveRecord::StatementInvalid.include( Niceql::ErrorExt ) if config.prettify_pg_errors && config.ar_using_pg_adapter?
  end

  def self.config
    @config ||= NiceQLConfig.new
  end

  if defined? ::ActiveRecord::Base
    ::ActiveRecord::Base.extend ArExtentions
    [::ActiveRecord::Relation, ::ActiveRecord::Associations::CollectionProxy].each { |klass| klass.send(:include, ArExtentions) }
  end

end
