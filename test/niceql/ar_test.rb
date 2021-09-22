require 'active_record'
require 'active_support/testing/declarative'
require 'test_helper'
require 'differ'
require 'niceql'
require 'byebug'

ActiveRecord::Base.logger = Logger.new(STDERR)

ActiveRecord::Base.establish_connection(
  adapter: "sqlite3",
  dbfile: ":memory:",
  database: 'niceql_test'
)

class ARTest < Minitest::Test
  extend ::ActiveSupport::Testing::Declarative

  test 'ar_using_pg_adapter? whenever AR is not defined will be false' do
    assert( !Niceql::NiceQLConfig.new.ar_using_pg_adapter? )
  end

  test 'ar_using_pg_adapter? whenever AR is < 6.1 ' do
    ActiveRecord::Base.stub(:connection_db_config, nil) {
      ActiveRecord::Base.stub(:connection_config, {adapter: "postgresql", encoding: "utf8", database: "niceql_test"}) {
        assert(Niceql::NiceQLConfig.new.ar_using_pg_adapter?)
      }
    }
  end
end