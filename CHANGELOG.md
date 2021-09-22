# 0.1.4
* Fix to issue https://github.com/alekseyl/niceql/pull/17#issuecomment-924278172. ActiveRecord base config is no longer a hash, 
so it does not have dig method, hence it's breaking the ar_using_pg_adapter? method. 
* active_record added as development dependency :( for proper testing cover. 

# 0.1.3

* ActiveRecord pg check for config now will try both connection_db_config and connection_config for adapter verification 
* prettify_pg_errors will not be set to true if ActiveRecord adapter is not using pg, i.e. ar_using_pg_adapter? is false. 
* rake dev dependency bumped according to security issues

# 0.1.24/25

* No features, just strict ruby dependency for >= 2.3,
* travis fix for ruby 2.3 and 2.6 added

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