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
    INLINE_VERBS = %w(WITH ASC IN COALESCE AS WHEN THEN ELSE END AND UNION ALL WITH ON DISTINCT INTERSECT EXCEPT EXISTS NOT COUNT ROUND CAST).join('| ')
    NEW_LINE_VERBS = 'SELECT|FROM|WHERE|CASE|ORDER BY|LIMIT|GROUP BY|LEFT JOIN|RIGHT JOIN|JOIN|HAVING|OFFSET|UPDATE'
    POSSIBLE_INLINER = /(ORDER BY|CASE)/
    VERBS = "#{INLINE_VERBS}|#{NEW_LINE_VERBS}"
    STRINGS = /("[^"]+")|('[^']+')/
    BRACKETS = '[\(\)]'


    def self.config
      Niceql.config
    end


    def self.prettify_err(err)
      prettify_pg_err( err.to_s )
    end


    def self.prettify_pg_err(err)
      err_line_num = err[/LINE \d+/][5..-1].to_i

      start_sql_line = err.lines[3][/(HINT|DETAIL)/] ? 4 : 3
      err_body = err.lines[start_sql_line..-1]
      err_quote = ( err.lines[1][/\.\.\..+\.\.\./] && err.lines[1][/\.\.\..+\.\.\./][3..-4] ) ||
          ( err.lines[1][/\.\.\..+/] && err.lines[1][/\.\.\..+/][3..-1] )

      # line 2 is err carret line
      # err.lines[1][/LINE \d+:/].length+1..-1 - is a position from error quote begin
      err_carret_line = err.lines[2][err.lines[1][/LINE \d+:/].length+1..-1]
      # err line painted red completly, so we just remembering it and use
      # to replace after paiting the verbs
      err_line = err_body[err_line_num-1]

      # when err line is too long postgres quotes it part in doble ...
      if err_quote
        err_quote_carret_offset = err_carret_line.length - err.lines[1].index( '...' ) + 3
        err_carret_line =  ' ' * ( err_line.index( err_quote ) + err_quote_carret_offset ) + "^\n"
      end

      # if mistake is on last string than err_line.last != \n so we need to prepend \n to carret line
      err_carret_line = "\n" + err_carret_line unless err_line.last == "\n"

      #colorizing verbs and strings
      err_body = err_body.join.gsub(/#{VERBS}/ ) { |verb| StringColorize.colorize_verb(verb) }
      err_body = err_body.gsub(STRINGS){ |str| StringColorize.colorize_str(str) }

      #reassemling error message
      err_body = err_body.lines
      err_body[err_line_num-1]= StringColorize.colorize_err( err_line )
      err_body.insert( err_line_num, StringColorize.colorize_err( err_carret_line ) )

      err.lines[0..start_sql_line-1].join + err_body.join
    end

    def self.prettify_sql( sql, colorize = true )
      indent = 0
      parentness = []

      #it's better to remove all new lines because it will break formatting
      sql = sql.gsub("\n", ' ')
      # remove any additional formatting
      sql = sql.gsub(/[ ]+/, ' ')

      sql = sql.gsub(STRINGS){ |str| StringColorize.colorize_str(str) } if colorize
      first_verb  = true

      sql.gsub( /(#{VERBS}|#{BRACKETS})/).with_index do |verb, index|
        add_new_line = false
        if 'SELECT' == verb
          indent += config.indentation_base if parentness.last.nil? || parentness.last[:nested]
          parentness.last[:nested] = true if parentness.last
          add_new_line = !first_verb
        elsif verb == '('
          next_closing_bracket = Regexp.last_match.post_match.index(')')
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
        first_verb = false
        verb = StringColorize.colorize_verb(verb) if !['(', ')'].include?(verb) && colorize
        add_new_line ? "\n#{' ' * indent}" + verb : verb
      end
    end
  end

  module PostgresAdapterNiceQL
    def exec_query(sql, name = "SQL", binds = [], prepare: false)
      # replacing sql with prettified sql, thats all
      super( Prettifier.prettify_sql(sql, false), name, binds, prepare: prepare )
    end
  end

  module ErrorExt
    def to_s
      if ActiveRecord::Base.configurations[Rails.env]['adapter'] == 'postgresql'
        Prettifier.prettify_err( super )
      else
        super
      end
    end
  end

  class NiceQLConfig
    attr_accessor :pg_adapter_with_nicesql

    attr_accessor :indentation_base

    attr_accessor :open_bracket_is_newliner

    def initialize
      self.pg_adapter_with_nicesql = false
      self.indentation_base = 2
      self.open_bracket_is_newliner = false
    end
  end


  def self.configure
    yield( config )

    if config.pg_adapter_with_nicesql
      ::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.include(PostgresAdapterNiceQL)
    end
  end

  def self.config
    @config ||= NiceQLConfig.new
  end


  if defined? ::ActiveRecord::Base
    ActiveRecord::StatementInvalid.include( Niceql::ErrorExt )
    ::ActiveRecord::Base.extend ArExtentions
    [::ActiveRecord::Relation, ::ActiveRecord::Associations::CollectionProxy].each { |klass| klass.send(:include, ArExtentions) }
  end

end


