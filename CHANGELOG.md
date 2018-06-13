# 0.1.23
 * +LATERAL verb
 * removed hidden rails dependencies PR(https://github.com/alekseyl/niceql/pull/9)
 
# 0.1.22
 * multi query formatting 

# 0.1.21
 * fix bug for SQL started with comment 
 
# 0.1.20
 * Add respect for SQL comments single lined, multi lined, and inline
 
# 0.1.19
 * add prettify_pg_errors to config - now pg errors prettified output is configurable, 
   default is true if ActiveRecord::Base defined and db adapter is pg 
 
 * tests for error prettifying 

# 0.1.18
 * add color to logger output
 
# 0.1.17
 * add test 
 * fix issue 1 for real
 
# 0.1.16
* Add prettify_active_record_log_output to rails config generator

# 0.1.15
* JOIN verb refactored, INNER|OUTER will be also colored properly
* prettify_active_record_log_output added to config, now you can set it to true 
  and sql will log prettified