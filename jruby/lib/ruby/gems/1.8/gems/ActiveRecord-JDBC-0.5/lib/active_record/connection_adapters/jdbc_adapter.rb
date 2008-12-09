require 'active_record/connection_adapters/abstract_adapter'
require 'java'
require 'active_record/connection_adapters/jdbc_adapter_spec'
require 'jdbc_adapter_internal'
require 'bigdecimal'

module ActiveRecord
  module ConnectionAdapters # :nodoc:
    module SchemaStatements
      # The original implementation of this had a bug, which modifies native_database_types.
      # This version allows us to cache that value.
      def type_to_sql(type, limit = nil, precision = nil, scale = nil) #:nodoc:
        native = native_database_types[type]
        column_type_sql = native.is_a?(Hash) ? native[:name] : native
        if type == :decimal # ignore limit, use precison and scale
          precision ||= native[:precision]
          scale ||= native[:scale]
          if precision
            if scale
              column_type_sql += "(#{precision},#{scale})"
            else
              column_type_sql += "(#{precision})"
            end
          else
            raise ArgumentError, "Error adding decimal column: precision cannot be empty if scale if specified" if scale
          end
          column_type_sql
        else
          limit ||= native[:limit]
          column_type_sql += "(#{limit})" if limit
          column_type_sql
        end
      end
    end
  end
end

module JdbcSpec
  module ActiveRecordExtensions
    def jdbc_connection(config)
      connection = ::ActiveRecord::ConnectionAdapters::JdbcConnection.new(config)
      ::ActiveRecord::ConnectionAdapters::JdbcAdapter.new(connection, logger, config)
    end
    alias jndi_connection jdbc_connection

    def embedded_driver(config)
      config[:username] ||= "sa"
      config[:password] ||= ""
      jdbc_connection(config)
    end
  end
end

module ActiveRecord
  class Base
    extend JdbcSpec::ActiveRecordExtensions

    alias :attributes_with_quotes_pre_oracle :attributes_with_quotes
    def attributes_with_quotes(include_primary_key = true) #:nodoc:
      aq = attributes_with_quotes_pre_oracle(include_primary_key)
      if connection.class == ConnectionAdapters::JdbcAdapter && (connection.is_a?(JdbcSpec::Oracle) || connection.is_a?(JdbcSpec::Mimer))
        aq[self.class.primary_key] = "?" if include_primary_key && aq[self.class.primary_key].nil?
      end
      aq
    end
  end

  module ConnectionAdapters
    module Java
      Class = java.lang.Class
      URL = java.net.URL
      URLClassLoader = java.net.URLClassLoader
    end

    module Jdbc
      Mutex = java.lang.Object.new
      DriverManager = java.sql.DriverManager
      Statement = java.sql.Statement
      Types = java.sql.Types

      # some symbolic constants for the benefit of the JDBC-based
      # JdbcConnection#indexes method
      module IndexMetaData
        INDEX_NAME  = 6
        NON_UNIQUE  = 4
        TABLE_NAME  = 3
        COLUMN_NAME = 9
      end

      module TableMetaData
        TABLE_CAT   = 1
        TABLE_SCHEM = 2
        TABLE_NAME  = 3
        TABLE_TYPE  = 4
      end

      module PrimaryKeyMetaData
        COLUMN_NAME = 4
      end
      
    end

    # I want to use JDBC's DatabaseMetaData#getTypeInfo to choose the best native types to
    # use for ActiveRecord's Adapter#native_database_types in a database-independent way,
    # but apparently a database driver can return multiple types for a given
    # java.sql.Types constant.  So this type converter uses some heuristics to try to pick
    # the best (most common) type to use.  It's not great, it would be better to just
    # delegate to each database's existin AR adapter's native_database_types method, but I
    # wanted to try to do this in a way that didn't pull in all the other adapters as
    # dependencies.  Suggestions appreciated.
    class JdbcTypeConverter
      # The basic ActiveRecord types, mapped to an array of procs that are used to #select
      # the best type.  The procs are used as selectors in order until there is only one
      # type left.  If all the selectors are applied and there is still more than one
      # type, an exception will be raised.
      AR_TO_JDBC_TYPES = {
        :string      => [ lambda {|r| Jdbc::Types::VARCHAR == r['data_type'].to_i},
                          lambda {|r| r['type_name'] =~ /^varchar/i},
                          lambda {|r| r['type_name'] =~ /^varchar$/i},
                          lambda {|r| r['type_name'] =~ /varying/i}],
        :text        => [ lambda {|r| [Jdbc::Types::LONGVARCHAR, Jdbc::Types::CLOB].include?(r['data_type'].to_i)},
                          lambda {|r| r['type_name'] =~ /^(text|clob)/i},
                          lambda {|r| r['type_name'] =~ /^character large object$/i},
                          lambda {|r| r['sql_data_type'] == 2005}],
        :integer     => [ lambda {|r| Jdbc::Types::INTEGER == r['data_type'].to_i},
                          lambda {|r| r['type_name'] =~ /^integer$/i},
                          lambda {|r| r['type_name'] =~ /^int4$/i},
                          lambda {|r| r['type_name'] =~ /^int$/i}],
        :decimal     => [ lambda {|r| Jdbc::Types::DECIMAL == r['data_type'].to_i},
                          lambda {|r| r['type_name'] =~ /^decimal$/i},
                          lambda {|r| r['type_name'] =~ /^numeric$/i},
                          lambda {|r| r['type_name'] =~ /^number$/i},
                          lambda {|r| r['precision'] == '38'},
                          lambda {|r| r['data_type'] == '2'}],
        :float       => [ lambda {|r| [Jdbc::Types::FLOAT,Jdbc::Types::DOUBLE, Jdbc::Types::REAL].include?(r['data_type'].to_i)},
                          lambda {|r| r['data_type'].to_i == Jdbc::Types::REAL}, #Prefer REAL to DOUBLE for Postgresql
                          lambda {|r| r['type_name'] =~ /^float/i},
                          lambda {|r| r['type_name'] =~ /^double$/i},
                          lambda {|r| r['type_name'] =~ /^real$/i},
                          lambda {|r| r['precision'] == '15'}],
        :datetime    => [ lambda {|r| Jdbc::Types::TIMESTAMP == r['data_type'].to_i},
                          lambda {|r| r['type_name'] =~ /^datetime$/i},
                          lambda {|r| r['type_name'] =~ /^timestamp$/i},
                          lambda {|r| r['type_name'] =~ /^date/i}],
        :timestamp   => [ lambda {|r| Jdbc::Types::TIMESTAMP == r['data_type'].to_i},
                          lambda {|r| r['type_name'] =~ /^timestamp$/i},
                          lambda {|r| r['type_name'] =~ /^datetime/i},
                          lambda {|r| r['type_name'] =~ /^date/i}],
        :time        => [ lambda {|r| Jdbc::Types::TIME == r['data_type'].to_i},
                          lambda {|r| r['type_name'] =~ /^time$/i},
                          lambda {|r| r['type_name'] =~ /^date/i}],
        :date        => [ lambda {|r| Jdbc::Types::DATE == r['data_type'].to_i},
                          lambda {|r| r['type_name'] =~ /^date$/i},
                          lambda {|r| r['type_name'] =~ /^date/i}],
        :binary      => [ lambda {|r| [Jdbc::Types::LONGVARBINARY,Jdbc::Types::BINARY,Jdbc::Types::BLOB].include?(r['data_type'].to_i)},
                          lambda {|r| r['type_name'] =~ /^blob/i},
                          lambda {|r| r['type_name'] =~ /sub_type 0$/i}, # For FireBird
                          lambda {|r| r['type_name'] =~ /^varbinary$/i}, # We want this sucker for Mimer
                          lambda {|r| r['type_name'] =~ /^binary$/i}, ],
        :boolean     => [ lambda {|r| [Jdbc::Types::TINYINT].include?(r['data_type'].to_i)},
                          lambda {|r| r['type_name'] =~ /^bool/i},
                          lambda {|r| r['data_type'] == '-7'},
                          lambda {|r| r['type_name'] =~ /^tinyint$/i},
                          lambda {|r| r['type_name'] =~ /^decimal$/i}],
      }

      def initialize(types)
        @types = types
        @types.each {|t| t['type_name'] ||= t['local_type_name']} # Sybase driver seems to want 'local_type_name'
      end

      def choose_best_types
        type_map = {}
        AR_TO_JDBC_TYPES.each_key do |k|
          typerow = choose_type(k)
          type_map[k] = { :name => typerow['type_name'].downcase }
          type_map[k][:limit] = typerow['precision'] && typerow['precision'].to_i if [:integer, :string, :decimal].include?(k)
          type_map[k][:limit] = 1 if k == :boolean
        end
        type_map
      end

      def choose_type(ar_type)
        procs = AR_TO_JDBC_TYPES[ar_type]
        types = @types
        procs.each do |p|
          new_types = types.select(&p)
          return new_types.first if new_types.length == 1
          types = new_types if new_types.length > 0
        end
        raise "unable to choose type for #{ar_type} from:\n#{types.collect{|t| t['type_name']}.inspect}"
      end
    end

    class JdbcDriver
      def initialize(name)
        @name = name
      end
      
      def driver_class
        @driver_class ||= begin
          driver_class_const = (@name[0...1].capitalize + @name[1..@name.length]).gsub(/\./, '_')
          Jdbc::Mutex.synchronized do
            unless Jdbc.const_defined?(driver_class_const)
              driver_class_name = @name
              Jdbc.module_eval do
                include_class(driver_class_name) { driver_class_const }
              end
            end
          end
          Jdbc.const_get(driver_class_const)
        end
      end
      
      def load
        Jdbc::DriverManager.registerDriver(create)
      end
      
      def create
        driver_class.new
      end
    end

    class JdbcColumn < Column
      attr_writer :limit, :precision
        
      COLUMN_TYPES = ::JdbcSpec.constants.map{|c| 
        ::JdbcSpec.const_get c }.select{ |c| 
        c.respond_to? :column_selector }.map{|c| 
        c.column_selector }.inject({}) { |h,val| 
        h[val[0]] = val[1]; h }
        
      def initialize(config, name, default, *args)
        ds = config[:driver].to_s
        for reg, func in COLUMN_TYPES
          if reg === ds
            func.call(config,self)
          end
        end
        super(name,default_value(default),*args)
        init_column(name, default, *args)
      end

      def init_column(*args)
      end

      def default_value(val)
        val
      end
    end

    class JdbcConnection
      attr_reader :adapter, :connection
      
      def initialize(config)
        @config = config.symbolize_keys!
        if @config[:jndi]
          configure_jndi
        else
          configure_jdbc
        end
        set_native_database_types
        @stmts = {}
      rescue Exception => e
        raise "The driver encountered an error: #{e}"
      end

      def reconnect!
        self.adapter.reconnect!
      end
      
      def adapter=(adapt)
        @adapter = adapt
        @tps = {}
        @native_types.each_pair {|k,v| @tps[k] = v.inject({}) {|memo,kv| memo.merge({kv.first => (kv.last.dup rescue kv.last)})}}
        adapt.modify_types(@tps)
      end
      
      # Default JDBC introspection for index metadata on the JdbcConnection.
      # This is currently used for migrations by JdbcSpec::HSQDLB and JdbcSpec::Derby
      # indexes with a little filtering tacked on.
      #
      # JDBC index metadata is denormalized (multiple rows may be returned for
      # one index, one row per column in the index), so a simple block-based
      # filter like that used for tables doesn't really work here.  Callers
      # should filter the return from this method instead.
      #
      # TODO: fix to use reconnect correctly
      def indexes(table_name, name = nil, schema_name = nil)
        metadata = @connection.getMetaData
        unless String === table_name
          table_name = table_name.to_s 
        else
          table_name = table_name.dup
        end
        table_name.upcase! if metadata.storesUpperCaseIdentifiers
        table_name.downcase! if metadata.storesLowerCaseIdentifiers
        resultset = metadata.getIndexInfo(nil, schema_name, table_name, false, false)
        primary_keys = primary_keys(table_name)
        indexes = []
        current_index = nil
        while resultset.next
          index_name = resultset.get_string(Jdbc::IndexMetaData::INDEX_NAME)
          next unless index_name
          index_name.downcase!
          column_name = resultset.get_string(Jdbc::IndexMetaData::COLUMN_NAME).downcase
          
          next if primary_keys.include? column_name
          
          # We are working on a new index
          if current_index != index_name
            current_index = index_name
            table_name = resultset.get_string(Jdbc::IndexMetaData::TABLE_NAME).downcase
            non_unique = resultset.get_boolean(Jdbc::IndexMetaData::NON_UNIQUE)

            # empty list for column names, we'll add to that in just a bit
            indexes << IndexDefinition.new(table_name, index_name, !non_unique, [])
          end
          
          # One or more columns can be associated with an index
          indexes.last.columns << column_name
        end
        resultset.close
        indexes
      rescue
        if @connection.is_closed
          reconnect!
          retry
        else
          raise
        end
      ensure
        metadata.close rescue nil
      end

      private
      def configure_jndi
        jndi = @config[:jndi].to_s
        ctx = javax.naming.InitialContext.new
        ds = ctx.lookup(jndi)
        set_connection ds.connection
        unless @config[:driver]
          @config[:driver] = @connection.meta_data.connection.java_class.name
        end
      end

      def configure_jdbc
        driver = @config[:driver].to_s
        user   = @config[:username].to_s
        pass   = @config[:password].to_s
        url    = @config[:url].to_s

        unless driver && url
          raise ArgumentError, "jdbc adapter requires driver class and url"
        end
        
        if driver =~ /mysql/i
          div = url =~ /\?/ ? '&' : '?'
          url = "#{url}#{div}zeroDateTimeBehavior=convertToNull&jdbcCompliantTruncation=false"
          @config[:url] = url
        end

        jdbc_driver = JdbcDriver.new(driver)
        jdbc_driver.load
        connection = begin
            Jdbc::DriverManager.getConnection(url, user, pass)
          rescue
            # bypass DriverManager to get around problem with dynamically loaded jdbc drivers
            props = java.util.Properties.new
            props.setProperty("user", user)
            props.setProperty("password", pass)
            jdbc_driver.create.connect(url, props)
          end
        set_connection connection
      end

    end

    class JdbcAdapter < AbstractAdapter
      attr_reader :config

      ADAPTER_TYPES = ::JdbcSpec.constants.map{|c| 
        ::JdbcSpec.const_get c }.select{ |c|
        c.respond_to? :adapter_selector }.map{|c| 
        c.adapter_selector }.inject({}) { |h,val| 
        h[val[0]] = val[1]; h }

      def initialize(connection, logger, config)
        super(connection, logger)
        @config = config
        ds = config[:driver].to_s
        for reg, func in ADAPTER_TYPES
          if reg === ds
            func.call(@config,self)
          end
        end
        connection.adapter = self
      end

      def modify_types(tp)
        tp
      end

      def adapter_name #:nodoc:
        'JDBC'
      end

      def supports_migrations?
        true
      end

      def native_database_types #:nodoc:
        @connection.native_database_types
      end

      def database_name #:nodoc:
        @connection.database_name
      end
      
      def native_sql_to_type(tp)
        if /^(.*?)\(([0-9]+)\)/ =~ tp
          tname = $1
          limit = $2.to_i
          ntype = native_database_types
          if ntype[:primary_key] == tp
            return :primary_key,nil
          else
            ntype.each do |name,val|
              if name == :primary_key
                next
              end
              if val[:name].downcase == tname.downcase && (val[:limit].nil? || val[:limit].to_i == limit)
                return name,limit
              end
            end
          end
        elsif /^(.*?)/ =~ tp
          tname = $1
          ntype = native_database_types
          if ntype[:primary_key] == tp
            return :primary_key,nil
          else
            ntype.each do |name,val|
              if val[:name].downcase == tname.downcase && val[:limit].nil?
                return name,nil
              end
            end
          end
        else
          return :string,255
        end
        return nil,nil
      end

      def reconnect!
        @connection.close rescue nil
        @connection = JdbcConnection.new(@config)
        @connection.adapter = self
        @connection
      end

      def select_all(sql, name = nil)
        select(sql, name)
      end

      def select_one(sql, name = nil)
        select(sql, name).first
      end

      def execute(sql, name = nil)
        log_no_bench(sql, name) do
          _execute(sql,name)
        end
      end

      # we need to do it this way, to allow Rails stupid tests to always work
      # even if we define a new execute method. Instead of mixing in a new
      # execute, an _execute should be mixed in.
      def _execute(sql, name = nil)
        case sql.strip
        when /\Ainsert/i:
            @connection.execute_insert(sql)
        when /\A\(?\s*(select|show)/i:
            @connection.execute_query(sql)
        else
          @connection.execute_update(sql)
        end
      end

      def update(sql, name = nil) #:nodoc:
        execute(sql, name)
      end

      def insert(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil)
        id = execute(sql, name = nil)
        id_value || id
      end

      def columns(table_name, name = nil)
        @connection.columns(table_name.to_s)
      end

      def tables
        @connection.tables
      end

      def indexes(table_name)
        @connection.indexes(table_name)
      end

      def begin_db_transaction
        @connection.begin
      end

      def commit_db_transaction
        @connection.commit
      end

      def rollback_db_transaction
        @connection.rollback
      end
      
      def write_large_object(*args)
        @connection.write_large_object(*args)
      end

      private
      def select(sql, name=nil)
        execute(sql,name)
      end

      def log_no_bench(sql, name)
        if block_given?
          if @logger and @logger.level <= Logger::INFO
            result = yield
            log_info(sql, name, 0)
            result
          else
            yield
          end
        else
          log_info(sql, name, 0)
          nil
        end
      rescue Exception => e
        # Log message and raise exception.
        message = "#{e.class.name}: #{e.message}: #{sql}"

        log_info(message, name, 0)
        raise ActiveRecord::StatementInvalid, message
      end
    end
  end
end
