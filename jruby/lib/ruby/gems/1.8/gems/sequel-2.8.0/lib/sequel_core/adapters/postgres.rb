require 'sequel_core/adapters/shared/postgres'

begin 
  require 'pg' 
  SEQUEL_POSTGRES_USES_PG = true
rescue LoadError => e 
  SEQUEL_POSTGRES_USES_PG = false
  begin
    require 'postgres'
    # Attempt to get uniform behavior for the PGconn object no matter
    # if pg, postgres, or postgres-pr is used.
    class PGconn
      unless method_defined?(:escape_string)
        if self.respond_to?(:escape)
          # If there is no escape_string instead method, but there is an
          # escape class method, use that instead.
          def escape_string(str)
            self.class.escape(str)
          end
        else
          # Raise an error if no valid string escaping method can be found.
          def escape_string(obj)
            raise Sequel::Error, "string escaping not supported with this postgres driver.  Try using ruby-pg, ruby-postgres, or postgres-pr."
          end
        end
      end
      unless method_defined?(:escape_bytea)
        if self.respond_to?(:escape_bytea)
          # If there is no escape_bytea instance method, but there is an
          # escape_bytea class method, use that instead.
          def escape_bytea(obj)
            self.class.escape_bytea(obj)
          end
        else
          begin
            require 'postgres-pr/typeconv/conv'
            require 'postgres-pr/typeconv/bytea'
            extend Postgres::Conversion
            # If we are using postgres-pr, use the encode_bytea method from
            # that.
            def escape_bytea(obj)
              self.class.encode_bytea(obj)
            end
            metaalias :unescape_bytea, :decode_bytea
          rescue
            # If no valid bytea escaping method can be found, create one that
            # raises an error
            def escape_bytea(obj)
              raise Sequel::Error, "bytea escaping not supported with this postgres driver.  Try using ruby-pg, ruby-postgres, or postgres-pr."
            end
            # If no valid bytea unescaping method can be found, create one that
            # raises an error
            def self.unescape_bytea(obj)
              raise Sequel::Error, "bytea unescaping not supported with this postgres driver.  Try using ruby-pg, ruby-postgres, or postgres-pr."
            end
          end
        end
      end
      alias_method :finish, :close unless method_defined?(:finish)
      alias_method :async_exec, :exec unless method_defined?(:async_exec)
      unless method_defined?(:block)
        def block(timeout=nil)
        end
      end
      unless defined?(CONNECTION_OK)
        CONNECTION_OK = -1
      end
    end
    class PGresult 
      alias_method :nfields, :num_fields unless method_defined?(:nfields) 
      alias_method :ntuples, :num_tuples unless method_defined?(:ntuples) 
      alias_method :ftype, :type unless method_defined?(:ftype) 
      alias_method :fname, :fieldname unless method_defined?(:fname) 
      alias_method :cmd_tuples, :cmdtuples unless method_defined?(:cmd_tuples) 
    end 
  rescue LoadError 
    raise e 
  end 
end

module Sequel
  # Top level module for holding all PostgreSQL-related modules and classes
  # for Sequel.
  module Postgres
    CONVERTED_EXCEPTIONS << PGError
    
    # Hash with integer keys and proc values for converting PostgreSQL types.
    PG_TYPES = {
      16 => lambda{ |s| s == 't' }, # boolean
      17 => lambda{ |s| Adapter.unescape_bytea(s).to_blob }, # bytea
      20 => lambda{ |s| s.to_i }, # int8
      21 => lambda{ |s| s.to_i }, # int2
      22 => lambda{ |s| s.to_i }, # int2vector
      23 => lambda{ |s| s.to_i }, # int4
      26 => lambda{ |s| s.to_i }, # oid
      700 => lambda{ |s| s.to_f }, # float4
      701 => lambda{ |s| s.to_f }, # float8
      790 => lambda{ |s| s.to_d }, # money
      1082 => lambda{ |s| @use_iso_date_format ? Date.new(*s.split("-").map{|x| x.to_i}) : s.to_date }, # date
      1083 => lambda{ |s| s.to_time }, # time without time zone
      1114 => lambda{ |s| s.to_sequel_time }, # timestamp without time zone
      1184 => lambda{ |s| s.to_sequel_time }, # timestamp with time zone
      1266 => lambda{ |s| s.to_time }, # time with time zone
      1700 => lambda{ |s| s.to_d }, # numeric
    }
    
    @use_iso_date_format = true

    # As an optimization, Sequel sets the date style to ISO, so that PostgreSQL provides
    # the date in a known format that Sequel can parse faster.  This can be turned off
    # if you require a date style other than ISO.
    metaattr_accessor :use_iso_date_format
    
    # PGconn subclass for connection specific methods used with the
    # pg, postgres, or postgres-pr driver.
    class Adapter < ::PGconn
      include Sequel::Postgres::AdapterMethods
      self.translate_results = false if respond_to?(:translate_results=)
      
      # Apply connection settings for this connection.  Current sets
      # the date style to ISO in order make Date object creation in ruby faster,
      # if Postgres.use_iso_date_format is true.
      def apply_connection_settings
        super
        if Postgres.use_iso_date_format
          sql = "SET DateStyle = 'ISO'"
          @db.log_info(sql)
          execute(sql)
        end
      end

      # Execute the given SQL with this connection.  If a block is given,
      # yield the results, otherwise, return the number of changed rows.
      def execute(sql, args=nil)
        q = nil
        begin
          q = args ? async_exec(sql, args) : async_exec(sql)
        rescue PGError
          begin
            s = status
          rescue PGError
            raise(Sequel::DatabaseDisconnectError)
          end
          status_ok = (s == Adapter::CONNECTION_OK)
          status_ok ? raise : raise(Sequel::DatabaseDisconnectError)
        ensure
          block if status_ok
        end
        begin
          block_given? ? yield(q) : q.cmd_tuples
        ensure
          q.clear
        end
      end

      # Reapply the connection settings if the connection is reset.
      def reset(*args, &block)
        super(*args, &block)
        apply_connection_settings
      end
      
      if SEQUEL_POSTGRES_USES_PG
        # Hash of prepared statements for this connection.  Keys are
        # string names of the server side prepared statement, and values
        # are SQL strings.
        def prepared_statements
          @prepared_statements ||= {}
        end
      end
      
      private
      
      # Return the requested values for the given row.
      def single_value(r)
        r.getvalue(0, 0) unless r.nil? || (r.ntuples == 0)
      end
    end
    
    # Database class for PostgreSQL databases used with Sequel and the
    # pg, postgres, or postgres-pr driver.
    class Database < Sequel::Database
      include Sequel::Postgres::DatabaseMethods
      
      set_adapter_scheme :postgres
      
      # Add the primary_keys and primary_key_sequences instance variables,
      # so we can get the correct return values for inserted rows.
      def initialize(*args)
        super
        @primary_keys = {}
        @primary_key_sequences = {}
      end

      # Connects to the database.  In addition to the standard database
      # options, using the :encoding or :charset option changes the
      # client encoding for the connection.
      def connect(server)
        opts = server_opts(server)
        conn = Adapter.connect(
          (opts[:host] unless opts[:host].blank?),
          opts[:port] || 5432,
          nil, '',
          opts[:database],
          opts[:user],
          opts[:password]
        )
        if encoding = opts[:encoding] || opts[:charset]
          if conn.respond_to?(:set_client_encoding)
            conn.set_client_encoding(encoding)
          else
            conn.async_exec("set client_encoding to '#{encoding}'")
          end
        end
        conn.db = self
        conn.apply_connection_settings
        conn
      end
      
      # Return instance of Sequel::Postgres::Dataset with the given options.
      def dataset(opts = nil)
        Postgres::Dataset.new(self, opts)
      end
      
      # Execute the given SQL with the given args on an available connection.
      def execute(sql, opts={}, &block)
        return execute_prepared_statement(sql, opts, &block) if Symbol === sql
        begin
          log_info(sql, opts[:arguments])
          synchronize(opts[:server]){|conn| conn.execute(sql, opts[:arguments], &block)}
        rescue => e
          log_info(e.message)
          raise_error(e, :classes=>CONVERTED_EXCEPTIONS)
        end
      end
      
      # Insert the values into the table and return the primary key (if
      # automatically generated).
      def execute_insert(sql, opts={})
        return execute(sql, opts) if Symbol === sql
        begin 
          log_info(sql, opts[:arguments])
          synchronize(opts[:server]) do |conn|
            conn.execute(sql, opts[:arguments])
            insert_result(conn, opts[:table], opts[:values])
          end
        rescue => e
          log_info(e.message)
          raise_error(e, :classes=>CONVERTED_EXCEPTIONS)
        end
      end
      
      private

      # PostgreSQL doesn't need the connection pool to convert exceptions.
      def connection_pool_default_options
        super.merge(:pool_convert_exceptions=>false)
      end
      
      # Disconnect given connection
      def disconnect_connection(conn)
        begin
          conn.finish
        rescue PGError
        end
      end
      
      # Execute the prepared statement with the given name on an available
      # connection, using the given args.  If the connection has not prepared
      # a statement with the given name yet, prepare it.  If the connection
      # has prepared a statement with the same name and different SQL,
      # deallocate that statement first and then prepare this statement.
      # If a block is given, yield the result, otherwise, return the number
      # of rows changed.  If the :insert option is passed, return the value
      # of the primary key for the last inserted row.
      def execute_prepared_statement(name, opts={})
        ps = prepared_statements[name]
        sql = ps.prepared_sql
        ps_name = name.to_s
        args = opts[:arguments]
        synchronize(opts[:server]) do |conn|
          unless conn.prepared_statements[ps_name] == sql
            if conn.prepared_statements.include?(ps_name)
              s = "DEALLOCATE #{ps_name}"
              log_info(s)
              conn.execute(s) unless conn.prepared_statements[ps_name] == sql
            end
            conn.prepared_statements[ps_name] = sql
            log_info("PREPARE #{ps_name} AS #{sql}")
            conn.prepare(ps_name, sql)
          end
          log_info("EXECUTE #{ps_name}", args)
          q = conn.exec_prepared(ps_name, args)
          if opts[:table] && opts[:values]
            insert_result(conn, opts[:table], opts[:values])
          else
            begin
              block_given? ? yield(q) : q.cmd_tuples
            ensure
              q.clear
            end
          end
        end
      end
    end
    
    # Dataset class for PostgreSQL datasets that use the pg, postgres, or
    # postgres-pr driver.
    class Dataset < Sequel::Dataset
      include Sequel::Postgres::DatasetMethods
      
      # Yield all rows returned by executing the given SQL and converting
      # the types.
      def fetch_rows(sql)
        cols = []
        execute(sql) do |res|
          res.nfields.times do |fieldnum|
            cols << [fieldnum, PG_TYPES[res.ftype(fieldnum)], res.fname(fieldnum).to_sym]
          end
          @columns = cols.map{|c| c.at(2)}
          res.ntuples.times do |recnum|
            converted_rec = {}
            cols.each do |fieldnum, type_proc, fieldsym|
              value = res.getvalue(recnum, fieldnum)
              converted_rec[fieldsym] = (value && type_proc) ? type_proc.call(value) : value
            end
            yield converted_rec
          end
        end
      end
      
      if SEQUEL_POSTGRES_USES_PG
        
        PREPARED_ARG_PLACEHOLDER = '$'.lit.freeze
        
        # PostgreSQL specific argument mapper used for mapping the named
        # argument hash to a array with numbered arguments.  Only used with
        # the pg driver.
        module ArgumentMapper
          include Sequel::Dataset::ArgumentMapper
          
          protected
          
          # Return an array of strings for each of the hash values, inserting
          # them to the correct position in the array.
          def map_to_prepared_args(hash)
            @prepared_args.map{|k| hash[k.to_sym].to_s}
          end

          private
          
          # PostgreSQL most of the time requires type information for each of
          # arguments to a prepared statement.  Handle this by allowing the
          # named argument to have a __* suffix, with the * being the type.
          # In the generated SQL, cast the bound argument to that type to
          # elminate ambiguity (and PostgreSQL from raising an exception).
          def prepared_arg(k)
            y, type = k.to_s.split("__")
            if i = @prepared_args.index(y)
              i += 1
            else
              @prepared_args << y
              i = @prepared_args.length
            end
            "#{prepared_arg_placeholder}#{i}#{"::#{type}" if type}".lit
          end
        end

        # Allow use of bind arguments for PostgreSQL using the pg driver.
        module BindArgumentMethods
          include ArgumentMapper
          
          private
          
          # Execute the given SQL with the stored bind arguments.
          def execute(sql, opts={}, &block)
            super(sql, {:arguments=>bind_arguments}.merge(opts), &block)
          end
          
          # Same as execute, explicit due to intricacies of alias and super.
          def execute_dui(sql, opts={}, &block)
            super(sql, {:arguments=>bind_arguments}.merge(opts), &block)
          end
          
          # Same as execute, explicit due to intricacies of alias and super.
          def execute_insert(sql, opts={}, &block)
            super(sql, {:arguments=>bind_arguments}.merge(opts), &block)
          end
        end
        
        # Allow use of server side prepared statements for PostgreSQL using the
        # pg driver.
        module PreparedStatementMethods
          include BindArgumentMethods
          include ::Sequel::Postgres::DatasetMethods::PreparedStatementMethods
          
          private
          
          # Execute the stored prepared statement name and the stored bind
          # arguments instead of the SQL given.
          def execute(sql, opts={}, &block)
            super(prepared_statement_name, opts, &block)
          end
          
          # Same as execute, explicit due to intricacies of alias and super.
          def execute_dui(sql, opts={}, &block)
            super(prepared_statement_name, opts, &block)
          end
          
          # Same as execute, explicit due to intricacies of alias and super.
          def execute_insert(sql, opts={}, &block)
            super(prepared_statement_name, opts, &block)
          end
        end
        
        # Execute the given type of statement with the hash of values.
        def call(type, hash, values=nil, &block)
          ps = to_prepared_statement(type, values)
          ps.extend(BindArgumentMethods)
          ps.call(hash, &block)
        end
        
        # Prepare the given type of statement with the given name, and store
        # it in the database to be called later.
        def prepare(type, name=nil, values=nil)
          ps = to_prepared_statement(type, values)
          ps.extend(PreparedStatementMethods)
          if name
            ps.prepared_statement_name = name
            db.prepared_statements[name] = ps
          end
          ps
        end
        
        private
        
        # PostgreSQL uses $N for placeholders instead of ?, so use a $
        # as the placeholder.
        def prepared_arg_placeholder
          PREPARED_ARG_PLACEHOLDER
        end
      end
    end
  end
end
