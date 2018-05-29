require 'test_helper'
require 'differ'
require 'niceql'

class NiceQLTest < Minitest::Test
  ETALON = <<~PRETTY_RESULT
SELECT some, COUNT(attributes), 
  CASE WHEN some > 10 THEN '[{"attr": 2}]'::jsonb[] ELSE '{}'::jsonb[] END AS combined_attribute, more 
  FROM some_table st 
  RIGHT INNER JOIN some_other so ON so.st_id = st.id 
  WHERE some NOT IN (
    SELECT other_some 
    FROM other_table 
    WHERE id IN ARRAY[1,2]::bigint[] 
  ) 
  ORDER BY some 
  GROUP BY some 
  HAVING 2 > 1
PRETTY_RESULT

  def test_niceql
    prettySQL = Niceql::Prettifier.prettify_sql( <<~PRETTIFY_ME, false )
      SELECT some, COUNT(attributes), CASE WHEN some > 10 THEN '[{"attr": 2}]'::jsonb[] ELSE '{}'::jsonb[] END AS combined_attribute, more 
      FROM some_table st RIGHT INNER JOIN some_other so ON so.st_id = st.id       WHERE some NOT IN (SELECT other_some FROM other_table WHERE id IN ARRAY[1,2]::bigint[] ) ORDER BY   some
      GROUP BY some       HAVING 2 > 1
    PRETTIFY_ME

    # ETALON goes with \n at the end and prettySQL with space :(
    assert( prettySQL.chop == ETALON.chop )
  end
end
