# Niceql

**ATTENTION: After ver 0.5.0 the ActiveRecord integration is provided via standalone gem: [rails_sql_prettifier](https://github.com/alekseyl/rails_sql_prettifier)!**

This is a small, nice, simple and zero dependency solution for SQL prettifying for Ruby. 
It can be used in an irb console without any dependencies ( run bin/console and look for examples ).

Any reasonable suggestions are welcome.
 
## Before/After 
### SQL prettifier: 
![alt text](https://github.com/alekseyl/niceql/raw/master/to_niceql.png "To_niceql")

### PG errors prettifier 

before: 
![alt text](https://github.com/alekseyl/niceql/raw/master/err_was.png "To_niceql")

after:
![alt text](https://github.com/alekseyl/niceql/raw/master/err_now.png "To_niceql")


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'niceql'
```

And then execute:

    $ bundle
    # if you are using rails, you may want to install niceql config:
    rails g niceql:install 

Or install it yourself as:

    $ gem install niceql

## Configuration

```ruby
Niceql.configure do |c|
  # Setting pg_adapter_with_nicesql to true will force formatting SQL queries
  # before execution. Formatted SQL will lead to much better SQL-query debugging and much more clearer error messages 
  # if you are using Postgresql as a data source.  
  # 
  # Adjusting pg_adapter in production is strongly discouraged! 
  # 
  # If you need to debug SQL queries in production use exec_niceql
  # default: false
  # uncomment next string to enable in development
  # c.pg_adapter_with_nicesql = Rails.env.development?
  
  # uncomment next string if you want to log prettified SQL inside ActiveRecord logging. 
  # default: false
  # c.prettify_active_record_log_output = true
  
  # Error prettifying is also configurable
  # default: defined? ::ActiveRecord::Base && ActiveRecord::Base.configurations[Rails.env]['adapter'] == 'postgresql'
  # c.prettify_pg_errors = defined? ::ActiveRecord::Base && ActiveRecord::Base.configurations[Rails.env]['adapter'] == 'postgresql'
  
  # spaces count for one indentation
  c.indentation_base = 2
  
  # setting open_bracket_is_newliner to true will start opening brackets '(' with nested subqueries from new line 
  # i.e. SELECT * FROM ( SELECT * FROM tags ) tags; will transform to: 
  # SELECT * 
  # FROM 
  # ( 
 #    SELECT * FROM tags 
 #  ) tags; 
 # when open_bracket_is_newliner is false: 
  # SELECT * 
  # FROM ( 
 #   SELECT * FROM tags 
 # ) tags; 
 # default: false
  c.open_bracket_is_newliner = false
end
```

## Usage

### With ActiveRecord ( you need rails_sql_prettifier for that! )

```ruby
  # puts colorized and formatted corresponding SQL query
  Model.scope.niceql
  
  # only formatting without colorization, you can run output of to_niceql as a SQL query in connection.execute  
  Model.scope.to_niceql
  
  # prettify PG errors if scope runs with any 
  Model.scope_with_err.exec_niceql 
```

### Without ActiveRecord

```ruby
   
    puts Niceql::Prettifier.prettify_sql("SELECT * FROM ( VALUES(1), (2) ) AS tmp")
    #=>  SELECT * 
    #=>  FROM ( VALUES(1), (2) ) AS tmp
    
    puts Niceql::Prettifier.prettify_multiple("SELECT * FROM ( VALUES(1), (2) ) AS tmp; SELECT * FROM table")
    
    #=>  SELECT * 
    #=>  FROM ( VALUES(1), (2) ) AS tmp;
    #=>
    #=>  SELECT * 
    #=>  FROM table
    

   puts Niceql::Prettifier.prettify_pg_err( pg_err_output, sql_query )
   
   # to get real nice result you should execute prettified version (i.e. execute( prettified_sql ) !) of query on your DB! 
   # otherwise you will not get such a nice output
    raw_sql = <<~SQL
     SELECT err 
     FROM ( VALUES(1), (2) )
     ORDER BY 1
    SQL

    puts Niceql::Prettifier.prettify_pg_err(<<~ERR, raw_sql )
        ERROR:  VALUES in FROM must have an alias
        LINE 2:  FROM ( VALUES(1), (2) )
                      ^
        HINT:  For example, FROM (VALUES ...) [AS] foo.
    ERR
       
    
    # ERROR:  VALUES in FROM must have an alias
    # LINE 2:  FROM ( VALUES(1), (2) )
    #               ^
    #     HINT:  For example, FROM (VALUES ...) [AS] foo.
    #     SELECT err
    #     FROM ( VALUES(1), (2) )
    #          ^
    #     ORDER BY 1

```

## Customizing colors
If your console support more colors or different schemes, or if you prefer different colorization, then you can override ColorizeString methods. Current colors are selected with dark and white console themes in mind, so a niceql colorization works good for dark, and good enough for white.

## Limitations

Right now gem detects only uppercased form of verbs with simple indentation and parsing options. 

## 

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/alekseyl/niceql.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
