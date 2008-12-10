require 'sequel_core/database/schema'

module Sequel
  # Array of all databases to which Sequel has connected.  If you are
  # developing an application that can connect to an arbitrary number of 
  # databases, delete the database objects from this or they will not get
  # garbage collected.
  DATABASES = []

  # A Database object represents a virtual connection to a database.
  # The Database class is meant to be subclassed by database adapters in order
  # to provide the functionality needed for executing queries.
  class Database
    include Schema::SQL

    # Array of supported database adapters
    ADAPTERS = %w'ado db2 dbi informix jdbc mysql odbc openbase oracle postgres sqlite'.collect{|x| x.to_sym}

    SQL_BEGIN = 'BEGIN'.freeze
    SQL_COMMIT = 'COMMIT'.freeze
    SQL_ROLLBACK = 'ROLLBACK'.freeze

    # Hash of adapters that have been used
    @@adapters = Hash.new

    # Whether to use the single threaded connection pool by default
    @@single_threaded = false

    # Whether to quote identifiers (columns and tables) by default
    @@quote_identifiers = true

    # Whether to upcase identifiers (columns and tables) by default
    @@upcase_identifiers = nil

    # The default schema to use
    attr_accessor :default_schema

    # Array of SQL loggers to use for this database
    attr_accessor :loggers

    # The options for this database
    attr_reader :opts
    
    # The connection pool for this database
    attr_reader :pool

    # The prepared statement objects for this database, keyed by name
    attr_reader :prepared_statements

    # Whether to quote identifiers (columns and tables) for this database
    attr_writer :quote_identifiers
    
    # Whether to upcase identifiers (columns and tables) for this database
    attr_writer :upcase_identifiers
    
    # Constructs a new instance of a database connection with the specified
    # options hash.
    #
    # Sequel::Database is an abstract class that is not useful by itself.
    #
    # Takes the following options:
    # * :default_schema : The default schema to use, should generally be nil
    # * :disconnection_proc: A proc used to disconnect the connection.
    # * :loggers : An array of loggers to use.
    # * :quote_identifiers : Whether to quote identifiers
    # * :single_threaded : Whether to use a single-threaded connection pool
    #
    # All options given are also passed to the ConnectionPool.  If a block
    # is given, it is used as the connection_proc for the ConnectionPool.
    def initialize(opts = {}, &block)
      @opts = opts
      
      @quote_identifiers = opts.include?(:quote_identifiers) ? opts[:quote_identifiers] : @@quote_identifiers
      @single_threaded = opts.include?(:single_threaded) ? opts[:single_threaded] : @@single_threaded
      @schemas = nil
      @default_schema = opts[:default_schema]
      @prepared_statements = {}
      @transactions = []
      @pool = (@single_threaded ? SingleThreadedPool : ConnectionPool).new(connection_pool_default_options.merge(opts), &block)
      @pool.connection_proc = proc{|server| connect(server)} unless block
      @pool.disconnection_proc = proc{|conn| disconnect_connection(conn)} unless opts[:disconnection_proc]

      @loggers = Array(opts[:logger]) + Array(opts[:loggers])
      ::Sequel::DATABASES.push(self)
    end
    
    ### Class Methods ###

    # The Database subclass for the given adapter scheme.
    # Raises Sequel::Error::AdapterNotFound if the adapter
    # could not be loaded.
    def self.adapter_class(scheme)
      scheme = scheme.to_s.gsub('-', '_').to_sym
      
      if (klass = @@adapters[scheme]).nil?
        # attempt to load the adapter file
        begin
          require "sequel_core/adapters/#{scheme}"
        rescue LoadError => e
          raise Error::AdapterNotFound, "Could not load #{scheme} adapter:\n  #{e.message}"
        end
        
        # make sure we actually loaded the adapter
        if (klass = @@adapters[scheme]).nil?
          raise Error::AdapterNotFound, "Could not load #{scheme} adapter"
        end
      end
      return klass
    end
        
    # Returns the scheme for the Database class.
    def self.adapter_scheme
      @scheme
    end
    
    # Connects to a database.  See Sequel.connect.
    def self.connect(conn_string, opts = {}, &block)
      if conn_string.is_a?(String)
        if conn_string =~ /\Ajdbc:/
          c = adapter_class(:jdbc)
          opts = {:uri=>conn_string}.merge(opts)
        else
          uri = URI.parse(conn_string)
          scheme = uri.scheme
          scheme = :dbi if scheme =~ /\Adbi-/
          c = adapter_class(scheme)
          uri_options = {}
          uri.query.split('&').collect{|s| s.split('=')}.each{|k,v| uri_options[k.to_sym] = v} unless uri.query.blank?
          opts = c.send(:uri_to_options, uri).merge(uri_options).merge(opts)
        end
      else
        opts = conn_string.merge(opts)
        c = adapter_class(opts[:adapter] || opts['adapter'])
      end
      # process opts a bit
      opts = opts.inject({}) do |m, kv| k, v = *kv
        k = :user if k.to_s == 'username'
        m[k.to_sym] = v
        m
      end
      if block
        begin
          yield(db = c.new(opts))
        ensure
          db.disconnect if db
          ::Sequel::DATABASES.delete(db)
        end
        nil
      else
        c.new(opts)
      end
    end

    # Sets the default quote_identifiers mode for new databases.
    # See Sequel.quote_identifiers=.
    def self.quote_identifiers=(value)
      @@quote_identifiers = value
    end

    # Sets the default single_threaded mode for new databases.
    # See Sequel.single_threaded=.
    def self.single_threaded=(value)
      @@single_threaded = value
    end

    # Sets the default quote_identifiers mode for new databases.
    # See Sequel.quote_identifiers=.
    def self.upcase_identifiers=(value)
      @@upcase_identifiers = value
    end

    ### Private Class Methods ###

    # Sets the adapter scheme for the Database class. Call this method in
    # descendnants of Database to allow connection using a URL. For example the
    # following:
    #
    #   class Sequel::MyDB::Database < Sequel::Database
    #     set_adapter_scheme :mydb
    #     ...
    #   end
    #
    # would allow connection using:
    #
    #   Sequel.connect('mydb://user:password@dbserver/mydb')
    def self.set_adapter_scheme(scheme) # :nodoc:
      @scheme = scheme
      @@adapters[scheme.to_sym] = self
    end
    
    # Converts a uri to an options hash. These options are then passed
    # to a newly created database object. 
    def self.uri_to_options(uri) # :nodoc:
      { :user => uri.user,
        :password => uri.password,
        :host => uri.host,
        :port => uri.port,
        :database => (m = /\/(.*)/.match(uri.path)) && (m[1]) }
    end
    
    private_class_method :set_adapter_scheme, :uri_to_options
    
    ### Instance Methods ###

    # Executes the supplied SQL statement. The SQL can be supplied as a string
    # or as an array of strings. If an array is given, comments and excessive 
    # white space are removed. See also Array#to_sql.
    def <<(sql)
      execute_ddl((Array === sql) ? sql.to_sql : sql)
    end
    
    # Returns a dataset from the database. If the first argument is a string,
    # the method acts as an alias for Database#fetch, returning a dataset for
    # arbitrary SQL:
    #
    #   DB['SELECT * FROM items WHERE name = ?', my_name].print
    #
    # Otherwise, acts as an alias for Database#from, setting the primary
    # table for the dataset:
    #
    #   DB[:items].sql #=> "SELECT * FROM items"
    def [](*args, &block)
      (String === args.first) ? fetch(*args, &block) : from(*args, &block)
    end
    
    # Call the prepared statement with the given name with the given hash
    # of arguments.
    def call(ps_name, hash={})
      prepared_statements[ps_name].call(hash)
    end
    
    # Connects to the database. This method should be overridden by descendants.
    def connect
      raise NotImplementedError, "#connect should be overridden by adapters"
    end
    
    # Returns a blank dataset
    def dataset
      ds = Sequel::Dataset.new(self)
    end
    
    # Disconnects all available connections from the connection pool.  If any
    # connections are currently in use, they will not be disconnected.
    def disconnect
      pool.disconnect
    end

    # Executes the given SQL. This method should be overridden in descendants.
    def execute(sql, opts={})
      raise NotImplementedError, "#execute should be overridden by adapters"
    end
    
    # Method that should be used when submitting any DDL (Data Definition
    # Language) SQL.  By default, calls execute_dui.
    def execute_ddl(sql, opts={}, &block)
      execute_dui(sql, opts, &block)
    end

    # Method that should be used when issuing a DELETE, UPDATE, or INSERT
    # statement.  By default, calls execute.
    def execute_dui(sql, opts={}, &block)
      execute(sql, opts, &block)
    end

    # Fetches records for an arbitrary SQL statement. If a block is given,
    # it is used to iterate over the records:
    #
    #   DB.fetch('SELECT * FROM items'){|r| p r}
    #
    # The method returns a dataset instance:
    #
    #   DB.fetch('SELECT * FROM items').print
    #
    # Fetch can also perform parameterized queries for protection against SQL
    # injection:
    #
    #   DB.fetch('SELECT * FROM items WHERE name = ?', my_name).print
    def fetch(sql, *args, &block)
      ds = dataset
      ds.opts[:sql] = Sequel::SQL::PlaceholderLiteralString.new(sql, args)
      ds.each(&block) if block
      ds
    end
    alias_method :>>, :fetch
    
    # Returns a new dataset with the from method invoked. If a block is given,
    # it is used as a filter on the dataset.
    def from(*args, &block)
      ds = dataset.from(*args)
      block ? ds.filter(&block) : ds
    end
    
    # Returns a single value from the database, e.g.:
    #
    #   # SELECT 1
    #   DB.get(1) #=> 1 
    #
    #   # SELECT version()
    #   DB.get(:version[]) #=> ...
    def get(expr)
      dataset.get(expr)
    end
    
    # Returns a string representation of the database object including the
    # class name and the connection URI (or the opts if the URI
    # cannot be constructed).
    def inspect
      "#<#{self.class}: #{(uri rescue opts).inspect}>" 
    end

    # Log a message at level info to all loggers.  All SQL logging
    # goes through this method.
    def log_info(message, args=nil)
      message = "#{message}; #{args.inspect}" if args
      @loggers.each{|logger| logger.info(message)}
    end

    # Return the first logger or nil if no loggers are being used.
    # Should only be used for backwards compatibility.
    def logger
      @loggers.first
    end

    # Replace the array of loggers with the given logger(s).
    def logger=(logger)
      @loggers = Array(logger)
    end

    # Returns true unless the database is using a single-threaded connection pool.
    def multi_threaded?
      !@single_threaded
    end
    
    # Returns a dataset modified by the given query block.  See Dataset#query.
    def query(&block)
      dataset.query(&block)
    end
    
    # Returns true if the database quotes identifiers.
    def quote_identifiers?
      @quote_identifiers
    end
    
    # Returns a new dataset with the select method invoked.
    def select(*args)
      dataset.select(*args)
    end
    
    # Default serial primary key options.
    def serial_primary_key_options
      {:primary_key => true, :type => :integer, :auto_increment => true}
    end
    
    # Returns true if the database is using a single-threaded connection pool.
    def single_threaded?
      @single_threaded
    end
    
    # Acquires a database connection, yielding it to the passed block.
    def synchronize(server=nil, &block)
      @pool.hold(server || :default, &block)
    end

    # Returns true if a table with the given name exists.  This requires a query
    # to the database unless this database object already has the schema for
    # the given table name.
    def table_exists?(name)
      if @schemas && @schemas[name]
        true
      else
        begin 
          from(name).first
          true
        rescue
          false
        end
      end
    end
    
    # Attempts to acquire a database connection.  Returns true if successful.
    # Will probably raise an error if unsuccessful.
    def test_connection(server=nil)
      synchronize(server){|conn|}
      true
    end

    # A simple implementation of SQL transactions. Nested transactions are not 
    # supported - calling #transaction within a transaction will reuse the 
    # current transaction. Should be overridden for databases that support nested 
    # transactions.
    def transaction(server=nil)
      synchronize(server) do |conn|
        return yield(conn) if @transactions.include?(Thread.current)
        log_info(begin_transaction_sql)
        conn.execute(begin_transaction_sql)
        begin
          @transactions << Thread.current
          yield(conn)
        rescue Exception => e
          log_info(rollback_transaction_sql)
          conn.execute(rollback_transaction_sql)
          transaction_error(e)
        ensure
          unless e
            log_info(commit_transaction_sql)
            conn.execute(commit_transaction_sql)
          end
          @transactions.delete(Thread.current)
        end
      end
    end
    
    # Typecast the value to the given column_type. Can be overridden in
    # adapters to support database specific column types.
    # This method should raise Sequel::Error::InvalidValue if assigned value
    # is invalid.
    def typecast_value(column_type, value)
      return nil if value.nil?
      case column_type
      when :integer
        begin
          Integer(value)
        rescue ArgumentError => e
          raise Sequel::Error::InvalidValue, e.message.inspect
        end
      when :string
        value.to_s
      when :float
        begin
          Float(value)
        rescue ArgumentError => e
          raise Sequel::Error::InvalidValue, e.message.inspect
        end
      when :decimal
        case value
        when BigDecimal
          value
        when String, Float
          value.to_d
        when Integer
          value.to_s.to_d
        else
          raise Sequel::Error::InvalidValue, "invalid value for BigDecimal: #{value.inspect}"
        end
      when :boolean
        case value
        when false, 0, "0", /\Af(alse)?\z/i
          false
        else
          value.blank? ? nil : true
        end
      when :date
        case value
        when Date
          value
        when DateTime, Time
          Date.new(value.year, value.month, value.day)
        when String
          value.to_date
        else
          raise Sequel::Error::InvalidValue, "invalid value for Date: #{value.inspect}"
        end
      when :time
        case value
        when Time
          value
        when String
          value.to_time
        else
          raise Sequel::Error::InvalidValue, "invalid value for Time: #{value.inspect}"
        end
      when :datetime
        raise(Sequel::Error::InvalidValue, "invalid value for Datetime: #{value.inspect}") unless value.is_one_of?(DateTime, Date, Time, String)
        if Sequel.datetime_class === value
          # Already the correct class, no need to convert
          value
        else
          # First convert it to standard ISO 8601 time, then
          # parse that string using the time class.
          (Time === value ? value.iso8601 : value.to_s).to_sequel_time
        end
      when :blob
        value.to_blob
      else
        value
      end
    end

    # Returns true if the database upcases identifiers.
    def upcase_identifiers?
      return @upcase_identifiers unless @upcase_identifiers.nil?
      @upcase_identifiers = @opts.include?(:upcase_identifiers) ? @opts[:upcase_identifiers] : (@@upcase_identifiers.nil? ? upcase_identifiers_default : @@upcase_identifiers)
    end
    
    # Returns the URI identifying the database.
    # This method can raise an error if the database used options
    # instead of a connection string.
    def uri
      uri = URI::Generic.new(
        self.class.adapter_scheme.to_s,
        nil,
        @opts[:host],
        @opts[:port],
        nil,
        "/#{@opts[:database]}",
        nil,
        nil,
        nil
      )
      uri.user = @opts[:user]
      uri.password = @opts[:password] if uri.user
      uri.to_s
    end
    alias_method :url, :uri
    
    private
    
    # SQL to BEGIN a transaction.
    def begin_transaction_sql
      SQL_BEGIN
    end

    # SQL to COMMIT a transaction.
    def commit_transaction_sql
      SQL_COMMIT
    end

    # The default options for the connection pool.
    def connection_pool_default_options
      {}
    end
    
    # SQL to ROLLBACK a transaction.
    def rollback_transaction_sql
      SQL_ROLLBACK
    end
    
    # Convert the given exception to a DatabaseError, keeping message
    # and traceback.
    def raise_error(exception, opts={})
      if !opts[:classes] || exception.is_one_of?(*opts[:classes])
        e = DatabaseError.new("#{exception.class} #{exception.message}")
        e.set_backtrace(exception.backtrace)
        raise e
      else
        raise exception
      end
    end
    
    # Split the schema information from the table
    def schema_and_table(table_name)
      schema_utility_dataset.schema_and_table(table_name)
    end

    # Return the options for the given server by merging the generic
    # options for all server with the specific options for the given
    # server specified in the :servers option.
    def server_opts(server)
      opts = if @opts[:servers] && server_options = @opts[:servers][server]
        case server_options
        when Hash
          @opts.merge(server_options)
        when Proc
          @opts.merge(server_options.call(self))
        else
          raise Error, 'Server opts should be a hash or proc'
        end
      else
        @opts.dup
      end
      opts.delete(:servers)
      opts
    end

    # Raise a database error unless the exception is an Error::Rollback.
    def transaction_error(e, *classes)
      raise_error(e, :classes=>classes) unless Error::Rollback === e
    end

    # Sets whether to upcase identifiers by default.  Should be
    # overridden in subclasses for databases that fold unquoted
    # identifiers to lower case instead of uppercase, such as
    # MySQL, PostgreSQL, and SQLite.
    def upcase_identifiers_default
      true
    end
  end
end

