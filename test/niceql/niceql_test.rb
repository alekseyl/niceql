require 'test_helper'
require 'differ'
require 'niceql'
require 'byebug'

::ActiveRecord::StatementInvalid.include( Niceql::ErrorExt )

class NiceQLTest < Minitest::Test
  extend ::ActiveSupport::Testing::Declarative

  def cmp_with_standard(niceql_result, etalon )
    if etalon != niceql_result
      puts 'ETALON:----------------------------'
      puts etalon
      puts 'Niceql result:---------------------'
      puts niceql_result
      puts 'DIFF:----------------------------'
      puts Differ.diff(etalon, niceql_result)
    end
    assert( etalon == niceql_result )
  end

  def test_niceql
    etalon = <<~PRETTY_RESULT
      -- valuable comment first line
      SELECT some,
        -- valuable comment to inline verb
        COUNT(attributes), /* some comment */
        CASE WHEN some > 10 THEN '[{"attr": 2}]'::jsonb[] ELSE '{}'::jsonb[] END AS combined_attribute, more
        -- valuable comment to newline verb
        FROM some_table st
        RIGHT INNER JOIN some_other so ON so.st_id = st.id
        /* multi line with semicolon;
           comment */
        WHERE some NOT IN (
          SELECT other_some
          FROM other_table
          WHERE id IN ARRAY[1,2]::bigint[]
        )
        ORDER BY some
        GROUP BY some
        HAVING 2 > 1;

      --comment to second query;
      SELECT other
        FROM other_table;
    PRETTY_RESULT


    prettySQL = Niceql::Prettifier.prettify_multiple(<<~PRETTIFY_ME, false)
      -- valuable comment first line
      SELECT some,
      -- valuable comment to inline verb
      COUNT(attributes), /* some comment */ CASE WHEN some > 10 THEN '[{"attr": 2}]'::jsonb[] ELSE '{}'::jsonb[] END AS combined_attribute, more 
      -- valuable comment to newline verb
      FROM some_table st RIGHT INNER JOIN some_other so ON so.st_id = st.id      
      /* multi line with semicolon;
         comment */
      WHERE some NOT IN (SELECT other_some FROM other_table WHERE id IN ARRAY[1,2]::bigint[] ) ORDER BY   some GROUP BY some       HAVING 2 > 1;
      --comment to second query;
         SELECT other FROM other_table;
    PRETTIFY_ME

    # ETALON goes with \n at the end :(
    cmp_with_standard(prettySQL, etalon.chop  )
  end

  def broken_sql_sample
      <<~SQL
        SELECT err
        FROM ( VALUES(1), (2) )
        WHERE id="100"
        ORDER BY 1
    SQL
  end

  def err_template
    <<~ERR
      SELECT err
      _COLORIZED_ERR_WHERE id="100"
      ORDER BY 1
    ERR
  end

  def test_error_prettifier
    err = <<~ERR
      ERROR: VALUES in FROM must have an alias
      LINE 2: FROM ( VALUES(1), (2) )
                   ^
      HINT:  For example, FROM (VALUES ...) [AS] foo.
    ERR

    sample_err = prepare_sample_err(err, err_template)

    cmp_with_standard(Niceql::Prettifier.prettify_pg_err(err, broken_sql_sample), sample_err )
    # err already has \n as last char so it goes err + sql NOT err + "\n" + sql
    cmp_with_standard(Niceql::Prettifier.prettify_pg_err(err + broken_sql_sample), sample_err )
  end

  test 'error without HINT and ...' do
    err = <<~ERR
      ERROR: VALUES in FROM must have an alias
      LINE 2: FROM ( VALUES(1), (2) )
                   ^
    ERR

    sample_err = prepare_sample_err(err, err_template)

    cmp_with_standard(Niceql::Prettifier.prettify_pg_err(err, broken_sql_sample), sample_err )
    # err already has \n as last char so it goes err + sql NOT err + "\n" + sql
    cmp_with_standard(Niceql::Prettifier.prettify_pg_err(err + broken_sql_sample), sample_err )
  end

  def prepare_sample_err( base_err, prt_err_sql )
    standard_err = base_err + prt_err_sql.gsub(/#{Niceql::Prettifier::VERBS}/ ) { |verb| Niceql::StringColorize.colorize_verb(verb) }
      .gsub(/#{Niceql::Prettifier::STRINGS }/ ) { |verb| Niceql::StringColorize.colorize_str(verb) }

    standard_err.gsub!('_COLORIZED_ERR_', Niceql::StringColorize.colorize_err( "FROM ( VALUES(1), (2) )\n")  +
      Niceql::StringColorize.colorize_err( "     ^\n" ) )
    standard_err
  end

  test 'Statement Invalid new format' do
    err = <<~ERR
      ERROR: VALUES in FROM must have an alias
      LINE 2: FROM ( VALUES(1), (2) )
                   ^
    ERR
    si = ActiveRecord::StatementInvalid.new( err, sql: broken_sql_sample)

    Niceql.config.stub(:prettify_pg_errors, true) do
      cmp_with_standard( si.to_s, prepare_sample_err(err, err_template) )
    end
  end

  test 'Statement Invalid old format' do
    err = <<~ERR
      ERROR: VALUES in FROM must have an alias
      LINE 2: FROM ( VALUES(1), (2) )
                   ^
    ERR
    si = ActiveRecord::StatementInvalid.new(err + broken_sql_sample)

    Niceql.config.stub(:prettify_pg_errors, true) do
      si.singleton_class.undef_method(:sql)
      assert_raises { si.sql }
      cmp_with_standard( si.to_s, prepare_sample_err(err, err_template) )
    end
  end
end
