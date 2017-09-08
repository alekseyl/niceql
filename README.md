# Niceql

This is small, nice, simple and dependentless solution for SQL prettifiyng for Ruby. 
It can be used in irb console without any dependencies ( run ./console from bin and look for examples ).

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
  # prettify to_sql 
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
   # to get real nice result you should execute on your DB prettified_sql! 
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

Right now it detect only uppercase verbs with simple indentation and parsing options. 
Also if your console support more colors or different schemes, or you prefer different colorization you can override ColorizeString 
methods. Current color are selected with dark and white console themes in mind, so it works good for dark, and good enough for white.


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/niceql.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
