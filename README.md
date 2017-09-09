# Niceql

This is a small, nice, simple and dependentless solution for SQL prettifiyng for Ruby. 
It can be used in an irb console without any dependencies ( run ./console from bin and look for examples ).

Any reasonable suggestions on formatting/coloring are welcome

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

Or install it yourself as:

    $ gem install niceql

## Usage

### With ActiveRecord

```ruby
  # puts colorized ( or not if you are willing so ) to_niceql ( you need to call puts otherwise to_niceql looks ugly  )
  Model.scope.puts_niceql
  
  # only formatting without colorization can run as a SQL query in connection.execute  
  Model.scope.to_niceql
  
  # prettify PG errors 
  Model.scope_with_err.explain_err 
```

### Without ActiveRecord

```ruby
   puts Niceql::Prettifier.prettify_sql("SELECT * FROM ( VALUES(1), (2) ) AS tmp")
   
   # see colors in irb %) 
   #=>  SELECT * 
   #=>  FROM ( VALUES(1), (2) ) AS tmp

   # rails combines err with query, so don't forget to do it yourself 
   # to get real nice result you should executeprettified version (i.e. execute( prettified_sql ) !) of query on your DB! 
   # otherwise you will not get such a nice output
   
   puts Niceql::Prettifier.prettify_pg_err(<<-ERR )
ERROR:  VALUES in FROM must have an alias
LINE 2:  FROM ( VALUES(1), (2) )
              ^
HINT:  For example, FROM (VALUES ...) [AS] foo.
 SELECT err 
 FROM ( VALUES(1), (2) )
 ORDER BY 1
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
## Limitations

Right now gem detects only uppercased form of verbs with very simple indentation and parsing options. 

## Customizing colors
If your console support more colors or different schemes, or if you prefer different colorization, then you can override ColorizeString methods. Current colors are selected with dark and white console themes in mind, so a niceql colorization works good for dark, and good enough for white.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/alekseyl/niceql.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
