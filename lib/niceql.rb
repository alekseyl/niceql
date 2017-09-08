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
    def explain_err
      begin
        connection.execute( "EXPLAIN #{to_niceql}" )
      rescue StandardError => e
        puts Prettifier.prettify_err(e )
      end
    end

    def to_niceql
      Prettifier.prettify_sql(to_sql, false)
    end

    def puts_niceql( colorize = true )
      puts Prettifier.prettify_sql( to_sql, colorize )
    end
  end

  module Prettifier
    INLINE_VERBS = %w(ASC IN AS WHEN THEN ELSE END AND UNION ALL WITH ON DISTINCT INTERSECT EXCEPT EXISTS NOT).join('| ')
    NEW_LINE_VERBS = 'SELECT|FROM|WHERE|CASE|ORDER BY|LIMIT|GROUP BY|WITH|LEFT JOIN|RIGHT JOIN|JOIN|HAVING|OFFSET'
    VERBS = "#{INLINE_VERBS}|#{NEW_LINE_VERBS}"
    STRINGS = /("[^"]+")|('[^']+')/
    BRACKETS = '[\(\)]'

    def self.prettify_err(err)
      if ActiveRecord::Base.configurations[Rails.env]['adapter'] == 'postgresql'
        prettify_pg_err( err.to_s )
      else
        puts err
      end
    end


    def self.prettify_pg_err(err)
      err_line_num = err[/LINE \d+/][5..-1].to_i
      start_sql_line = err.lines[3][/HINT/] ? 4 : 3
      err_body = err.lines[start_sql_line..-1]
      err_line = StringColorize.colorize_err( err_body[err_line_num-1] )

      err_body = err_body.join.gsub(/#{VERBS}/ ) { |verb| StringColorize.colorize_verb(verb) }
      err_body = err_body.gsub(STRINGS){ |str| StringColorize.colorize_str(str) }

      err_body = err_body.lines
      err_body[err_line_num-1]= err_line
      err_body.insert( err_line_num, StringColorize.colorize_err( err.lines[2][err.lines[1][/LINE \d+:/].length+1..-1] ) )
      puts err.lines[0..start_sql_line-1].join + err_body.join
    end

    def self.prettify_sql( sql, colorize = true )
      indent = 0
      parentness = []

      sql = sql.gsub(STRINGS){ |str| StringColorize.colorize_str(str) } if colorize
      first_verb  = true

      sql.gsub( /(#{VERBS}|#{BRACKETS})/) do |verb|
        add_new_line = false
        if 'SELECT' == verb
          indent += 1
          parentness.last[:nested] = true if parentness.last
          add_new_line = !first_verb
          first_verb = false
        elsif verb == '('
          parentness << { nested: false }
          indent += 1
        elsif verb == ')'
          # this also covers case when right bracket is used without corresponding left one
          add_new_line = parentness.last.nil? || parentness.last[:nested]
          indent -= add_new_line ? 2 : 1
          indent = 0 if indent < 0
          parentness.pop
        elsif verb == 'ORDER BY'
          # in postgres ORDER BY can be used in aggregation function this will keep it
          # inline with its agg function
          add_new_line = parentness.last.nil? || parentness.last[:nested]
        else
          add_new_line = verb[/(#{INLINE_VERBS})/].nil?
        end
        verb = StringColorize.colorize_verb(verb) if !['(', ')'].include?(verb) && colorize
        add_new_line ? "\n#{' ' * indent}" + verb : verb
      end
    end
  end

  if defined? ::ActiveRecord::Base
    ::ActiveRecord::Base.extend ArExtentions
    [::ActiveRecord::Relation, ::ActiveRecord::Associations::CollectionProxy].each { |klass| klass.send(:include, ArExtentions) }
  end
end
