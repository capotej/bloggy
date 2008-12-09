# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{ActiveRecord-JDBC}
  s.version = "0.5"

  s.required_rubygems_version = nil if s.respond_to? :required_rubygems_version=
  s.authors = ["Nick Sieger, Ola Bini and JRuby contributors"]
  s.cert_chain = nil
  s.date = %q{2007-08-24}
  s.description = %q{ActiveRecord-JDBC is a database adapter for Rails' ActiveRecord component that can be used with JRuby[http://www.jruby.org/].  It allows use of virtually any JDBC-compliant database with your JRuby on Rails application.}
  s.email = %q{nick@nicksieger.com, ola.bini@gmail.com}
  s.extra_rdoc_files = ["History.txt", "Manifest.txt", "README.txt"]
  s.files = ["History.txt", "Manifest.txt", "README.txt", "Rakefile", "LICENSE", "lib/active_record/connection_adapters/derby_adapter.rb", "lib/active_record/connection_adapters/h2_adapter.rb", "lib/active_record/connection_adapters/hsqldb_adapter.rb", "lib/active_record/connection_adapters/jdbc_adapter.rb", "lib/active_record/connection_adapters/jdbc_adapter_spec.rb", "lib/active_record/connection_adapters/jndi_adapter.rb", "lib/active_record/connection_adapters/mysql_adapter.rb", "lib/active_record/connection_adapters/oracle_adapter.rb", "lib/active_record/connection_adapters/postgresql_adapter.rb", "lib/jdbc_adapter/jdbc_db2.rb", "lib/jdbc_adapter/jdbc_derby.rb", "lib/jdbc_adapter/jdbc_firebird.rb", "lib/jdbc_adapter/jdbc_hsqldb.rb", "lib/jdbc_adapter/jdbc_mimer.rb", "lib/jdbc_adapter/jdbc_mssql.rb", "lib/jdbc_adapter/jdbc_mysql.rb", "lib/jdbc_adapter/jdbc_oracle.rb", "lib/jdbc_adapter/jdbc_postgre.rb", "lib/jdbc_adapter/missing_functionality_helper.rb", "lib/jdbc_adapter.rb", "lib/jdbc_adapter_internal.jar", "test/activerecord/connection_adapters/type_conversion_test.rb", "test/activerecord/connections/native_jdbc_mysql/connection.rb", "test/db/derby.rb", "test/db/h2.rb", "test/db/hsqldb.rb", "test/db/jdbc.rb", "test/db/jndi_config.rb", "test/db/logger.rb", "test/db/mysql.rb", "test/db/postgres.rb", "test/derby_multibyte_test.rb", "test/derby_simple_test.rb", "test/generic_jdbc_connection_test.rb", "test/h2_simple_test.rb", "test/hsqldb_simple_test.rb", "test/jdbc_adapter/jdbc_db2_test.rb", "test/jdbc_common.rb", "test/jndi_test.rb", "test/manualTestDatabase.rb", "test/minirunit/testConnect.rb", "test/minirunit/testH2.rb", "test/minirunit/testHsqldb.rb", "test/minirunit/testLoadActiveRecord.rb", "test/minirunit/testMysql.rb", "test/minirunit/testRawSelect.rb", "test/minirunit.rb", "test/models/auto_id.rb", "test/models/data_types.rb", "test/models/entry.rb", "test/mysql_simple_test.rb", "test/postgres_simple_test.rb", "test/simple.rb", "lib/tasks/jdbc_databases.rake", "src/java/JdbcAdapterInternalService.java", "src/java/JDBCDerbySpec.java", "src/java/JDBCMySQLSpec.java"]
  s.has_rdoc = true
  s.homepage = %q{http://jruby-extras.rubyforge.org/ActiveRecord-JDBC}
  s.rdoc_options = ["--main", "README.txt"]
  s.require_paths = ["lib"]
  s.required_ruby_version = Gem::Requirement.new("> 0.0.0")
  s.rubyforge_project = %q{jruby-extras}
  s.rubygems_version = %q{1.3.1}
  s.summary = %q{JDBC adapter for ActiveRecord, for use within JRuby on Rails.}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 1

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end
