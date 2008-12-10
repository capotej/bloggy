# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{sequel}
  s.version = "2.8.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Jeremy Evans"]
  s.date = %q{2008-12-05}
  s.default_executable = %q{sequel}
  s.description = %q{The Database Toolkit for Ruby}
  s.email = %q{code@jeremyevans.net}
  s.executables = ["sequel"]
  s.extra_rdoc_files = ["README", "CHANGELOG", "COPYING", "doc/advanced_associations.rdoc", "doc/cheat_sheet.rdoc", "doc/dataset_filtering.rdoc", "doc/prepared_statements.rdoc", "doc/schema.rdoc", "doc/sharding.rdoc"]
  s.files = ["COPYING", "CHANGELOG", "README", "Rakefile", "bin/sequel", "doc/advanced_associations.rdoc", "doc/cheat_sheet.rdoc", "doc/dataset_filtering.rdoc", "doc/prepared_statements.rdoc", "doc/schema.rdoc", "doc/sharding.rdoc", "spec/adapters", "spec/adapters/ado_spec.rb", "spec/adapters/informix_spec.rb", "spec/adapters/mysql_spec.rb", "spec/adapters/oracle_spec.rb", "spec/adapters/postgres_spec.rb", "spec/adapters/spec_helper.rb", "spec/adapters/sqlite_spec.rb", "spec/integration", "spec/integration/dataset_test.rb", "spec/integration/eager_loader_test.rb", "spec/integration/prepared_statement_test.rb", "spec/integration/schema_test.rb", "spec/integration/spec_helper.rb", "spec/integration/type_test.rb", "spec/rcov.opts", "spec/sequel_core", "spec/sequel_core/connection_pool_spec.rb", "spec/sequel_core/core_ext_spec.rb", "spec/sequel_core/core_sql_spec.rb", "spec/sequel_core/database_spec.rb", "spec/sequel_core/dataset_spec.rb", "spec/sequel_core/expression_filters_spec.rb", "spec/sequel_core/migration_spec.rb", "spec/sequel_core/object_graph_spec.rb", "spec/sequel_core/pretty_table_spec.rb", "spec/sequel_core/schema_generator_spec.rb", "spec/sequel_core/schema_spec.rb", "spec/sequel_core/spec_helper.rb", "spec/sequel_model", "spec/sequel_model/association_reflection_spec.rb", "spec/sequel_model/associations_spec.rb", "spec/sequel_model/base_spec.rb", "spec/sequel_model/caching_spec.rb", "spec/sequel_model/dataset_methods_spec.rb", "spec/sequel_model/eager_loading_spec.rb", "spec/sequel_model/hooks_spec.rb", "spec/sequel_model/inflector_spec.rb", "spec/sequel_model/model_spec.rb", "spec/sequel_model/plugins_spec.rb", "spec/sequel_model/record_spec.rb", "spec/sequel_model/schema_spec.rb", "spec/sequel_model/spec_helper.rb", "spec/sequel_model/validations_spec.rb", "spec/spec.opts", "spec/spec_config.rb.example", "spec/spec_config.rb", "lib/sequel.rb", "lib/sequel_core.rb", "lib/sequel_core", "lib/sequel_core/adapters", "lib/sequel_core/adapters/ado.rb", "lib/sequel_core/adapters/db2.rb", "lib/sequel_core/adapters/dbi.rb", "lib/sequel_core/adapters/informix.rb", "lib/sequel_core/adapters/jdbc.rb", "lib/sequel_core/adapters/jdbc", "lib/sequel_core/adapters/jdbc/mysql.rb", "lib/sequel_core/adapters/jdbc/oracle.rb", "lib/sequel_core/adapters/jdbc/postgresql.rb", "lib/sequel_core/adapters/jdbc/sqlite.rb", "lib/sequel_core/adapters/mysql.rb", "lib/sequel_core/adapters/odbc.rb", "lib/sequel_core/adapters/openbase.rb", "lib/sequel_core/adapters/oracle.rb", "lib/sequel_core/adapters/postgres.rb", "lib/sequel_core/adapters/shared", "lib/sequel_core/adapters/shared/mssql.rb", "lib/sequel_core/adapters/shared/mysql.rb", "lib/sequel_core/adapters/shared/oracle.rb", "lib/sequel_core/adapters/shared/postgres.rb", "lib/sequel_core/adapters/shared/sqlite.rb", "lib/sequel_core/adapters/shared/progress.rb", "lib/sequel_core/adapters/sqlite.rb", "lib/sequel_core/connection_pool.rb", "lib/sequel_core/core_ext.rb", "lib/sequel_core/core_sql.rb", "lib/sequel_core/database.rb", "lib/sequel_core/database", "lib/sequel_core/database/schema.rb", "lib/sequel_core/dataset.rb", "lib/sequel_core/dataset", "lib/sequel_core/dataset/callback.rb", "lib/sequel_core/dataset/convenience.rb", "lib/sequel_core/dataset/pagination.rb", "lib/sequel_core/dataset/prepared_statements.rb", "lib/sequel_core/dataset/query.rb", "lib/sequel_core/dataset/schema.rb", "lib/sequel_core/dataset/sql.rb", "lib/sequel_core/dataset/unsupported.rb", "lib/sequel_core/dataset/stored_procedures.rb", "lib/sequel_core/deprecated.rb", "lib/sequel_core/exceptions.rb", "lib/sequel_core/migration.rb", "lib/sequel_core/object_graph.rb", "lib/sequel_core/pretty_table.rb", "lib/sequel_core/schema.rb", "lib/sequel_core/schema", "lib/sequel_core/schema/generator.rb", "lib/sequel_core/schema/sql.rb", "lib/sequel_core/sql.rb", "lib/sequel_model.rb", "lib/sequel_model", "lib/sequel_model/association_reflection.rb", "lib/sequel_model/associations.rb", "lib/sequel_model/base.rb", "lib/sequel_model/caching.rb", "lib/sequel_model/dataset_methods.rb", "lib/sequel_model/eager_loading.rb", "lib/sequel_model/hooks.rb", "lib/sequel_model/inflector.rb", "lib/sequel_model/plugins.rb", "lib/sequel_model/record.rb", "lib/sequel_model/schema.rb", "lib/sequel_model/validations.rb"]
  s.has_rdoc = true
  s.homepage = %q{http://sequel.rubyforge.org}
  s.rdoc_options = ["--quiet", "--line-numbers", "--inline-source", "--title", "Sequel: The Database Toolkit for Ruby", "--main", "README"]
  s.require_paths = ["lib"]
  s.required_ruby_version = Gem::Requirement.new(">= 1.8.4")
  s.rubyforge_project = %q{sequel}
  s.rubygems_version = %q{1.3.1}
  s.summary = %q{The Database Toolkit for Ruby}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end
