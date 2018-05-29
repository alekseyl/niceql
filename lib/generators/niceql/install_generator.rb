module Niceql
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("../../templates", __FILE__)
      desc "Creates Niceql initializer for your application"

      def copy_initializer
        template "niceql_initializer.rb", "config/initializers/niceql.rb"

        puts "Install complete!"
      end
    end
  end
end