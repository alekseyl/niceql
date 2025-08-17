# frozen_string_literal: true

require "test_helper"
require "differ"
require "byebug"
require "awesome_print"

class NiceQLTest < Minitest::Test
  extend ::ActiveSupport::Testing::Declarative

  def assert_equal_standard(niceql_result, etalon)
    if etalon != niceql_result
      puts "ETALON:----------------------------"
      puts etalon
      puts "Niceql result:---------------------"
      puts niceql_result
      puts "DIFF:----------------------------"
      puts Differ.diff(etalon, niceql_result)
    end

    raise "Not equal" unless etalon == niceql_result
  end

  def test_niceql
    etalon = <<~PRETTY_RESULT
      -- valuable comment first line
      SELECT some,
        -- valuable comment to inline keyword
        column2, COUNT(attributes), /* some comment */#{" "}
        CASE WHEN some > 10 THEN '[{"attr": 2}]'::jsonb[] ELSE '{}'::jsonb[] END AS combined_attribute, more
        -- valuable comment to newline keyword
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
      --comment to second query with semicolon;
      SELECT other."column"
        FROM "table"
        WHERE id = 1;
      -- third query with complex string literals and UPDATE
      UPDATE some_table
        SET string='
        multiline with   3 spaces string
      ', second_multiline_str = 'line one'#{" "}
        'line two', dollar_quoted_string = $$ I'll    be back $$, tagged_dollar_quoted_string = $tag$#{" "}
          with surprise $$!! $$  $not_tag$ still inside first string $not_tag$#{" "}
       $tag$
        WHERE id = 1 AND SELECT_id = 2;
    PRETTY_RESULT

    pretty_sql = Niceql::Prettifier.prettify_multiple(<<~PRETTIFY_ME, false)
      -- valuable comment first line
      SELECT some,
      -- valuable comment to inline keyword
      column2, COUNT(attributes), /* some comment */ CASE WHEN some > 10 THEN '[{"attr": 2}]'::jsonb[] ELSE '{}'::jsonb[] END AS combined_attribute, more#{" "}
      -- valuable comment to newline keyword
      FROM some_table st RIGHT INNER JOIN some_other so ON so.st_id = st.id#{"      "}
      /* multi line with semicolon;
         comment */
      WHERE some NOT IN (SELECT other_some FROM other_table WHERE id IN ARRAY[1,2]::bigint[] ) ORDER BY   some GROUP BY some       HAVING 2 > 1;
      --comment to second query with semicolon;
      SELECT other."column" FROM "table" WHERE id = 1;

      -- third query with complex string literals and UPDATE
      UPDATE some_table SET string='
        multiline with   3 spaces string
      ',  second_multiline_str = 'line one'#{" "}
           'line two',#{" "}
       dollar_quoted_string = $$ I'll    be back $$,
       tagged_dollar_quoted_string = $tag$#{" "}
          with surprise $$!! $$  $not_tag$ still inside first string $not_tag$#{" "}
       $tag$ WHERE id = 1 AND SELECT_id = 2;
    PRETTIFY_ME

    # ETALON goes with \n at the end :(
    assert_equal_standard(pretty_sql, etalon.chop)
  end

  def test_regression_when_no_comments_present
    etalon = <<~ETALON
      SELECT "webinars".*
        FROM "webinars"
        WHERE "webinars"."deleted_at" IS NULL
    ETALON

    prettified = Niceql::Prettifier.prettify_multiple(<<~PRETTIFY_ME, false)
      SELECT "webinars".* FROM "webinars" WHERE "webinars"."deleted_at" IS NULL
    PRETTIFY_ME

    assert_equal_standard(prettified.chop, etalon.chop)
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

  test "error prettifier" do
    err = <<~ERR
      ERROR: VALUES in FROM must have an alias
      LINE 2: FROM ( VALUES(1), (2) )
                   ^
      HINT:  For example, FROM (VALUES ...) [AS] foo.
    ERR

    sample_err = prepare_sample_err(err, err_template)

    assert_equal_standard(Niceql::Prettifier.prettify_pg_err(err, broken_sql_sample), sample_err)
    # err already has \n as last char so it goes err + sql NOT err + "\n" + sql
    assert_equal_standard(Niceql::Prettifier.prettify_pg_err(err + broken_sql_sample), sample_err)
  end

  test "error without HINT and ..." do
    err = <<~ERR
      ERROR: VALUES in FROM must have an alias
      LINE 2: FROM ( VALUES(1), (2) )
                   ^
    ERR

    sample_err = prepare_sample_err(err, err_template)

    assert_equal_standard(Niceql::Prettifier.prettify_pg_err(err, broken_sql_sample), sample_err)
    # err already has \n as last char so it goes err + sql NOT err + "\n" + sql
    assert_equal_standard(Niceql::Prettifier.prettify_pg_err(err + broken_sql_sample), sample_err)
  end

  def prepare_sample_err(base_err, prt_err_sql)
    standard_err = base_err + prt_err_sql.gsub(/#{Niceql::Prettifier::KEYWORDS}/) do |keyword|
                                Niceql::StringColorize.colorize_keyword(keyword)
                              end
      .gsub(/#{Niceql::Prettifier::STRINGS}/) { |keyword| Niceql::StringColorize.colorize_str(keyword) }

    standard_err.gsub!("_COLORIZED_ERR_", Niceql::StringColorize.colorize_err("FROM ( VALUES(1), (2) )\n") +
      Niceql::StringColorize.colorize_err("     ^\n"))
    standard_err
  end

  test "% usage does not throw an error" do
    etalon = <<~PERCENTAGE
      SELECT "clients".*
        FROM "clients"
        WHERE (id % 10 = 9)
    PERCENTAGE

    prettified = Niceql::Prettifier.prettify_multiple(<<~ISSUE, false)
      SELECT "clients".* FROM "clients" WHERE (id % 10 = 9)
    ISSUE

    assert_equal_standard(prettified.chop, etalon.chop)
  end
end
