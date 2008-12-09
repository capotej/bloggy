module ::ActiveRecord
  class Base
    # After setting large objects to empty, write data back with a helper method
    after_save :write_lobs
    def write_lobs() #:nodoc:
      if connection.is_a?(JdbcSpec::Oracle)
        self.class.columns.select { |c| c.sql_type =~ /LOB\(|LOB$/i }.each { |c|
          value = self[c.name]
          value = value.to_yaml if unserializable_attribute?(c.name, c)
          next if value.nil?  || (value == '')

          connection.write_large_object(c.type == :binary, c.name, self.class.table_name, self.class.primary_key, quote_value(id), value)
        }
      end
    end

    private :write_lobs
  end
end

module ::JdbcSpec
  module ActiveRecordExtensions
    def oracle_connection(config)
      config[:port] ||= 1521
      config[:url] ||= "jdbc:oracle:thin:@#{config[:host]}:#{config[:port]}:#{config[:database]}"
      config[:driver] ||= "oracle.jdbc.driver.OracleDriver"
      jdbc_connection(config)
    end
  end
  
  module Oracle
    def self.column_selector
      [/oracle/i, lambda {|cfg,col| col.extend(::JdbcSpec::Oracle::Column)}]
    end

    def self.adapter_selector
      [/oracle/i, lambda {|cfg,adapt| adapt.extend(::JdbcSpec::Oracle)}]
    end
    
    module Column
      def type_cast(value)
        return nil if value.nil? || value =~ /^\s*null\s*$/i
        case type
        when :string   then value
        when :integer  then defined?(value.to_i) ? value.to_i : (value ? 1 : 0)
        when :primary_key then defined?(value.to_i) ? value.to_i : (value ? 1 : 0) 
        when :float    then value.to_f
        when :datetime then JdbcSpec::Oracle::Column.cast_to_date_or_time(value)
        when :time     then JdbcSpec::Oracle::Column.cast_to_time(value)
        when :decimal   then self.class.value_to_decimal(value)
        when :boolean   then self.class.value_to_boolean(value)
        else value
        end
      end
      
      def type_cast_code(var_name)
        return "JdbcSpec::Oracle::Column.cast_to_date_or_time(#{var_name})" if type == :datetime
        super
      end
      
      private
      def simplified_type(field_type)      
        case field_type
        when /char/i                           : :string
        when /float|double/i                   : :float
        when /int/i                            : :integer
        when /num|dec|real/i                   : @scale == 0 ? :integer : :decimal
        when /date|time/i                      : :datetime
        when /clob/i                           : :text
        when /blob/i                           : :binary
        end
      end

      def self.cast_to_date_or_time(value)
        return value if value.is_a? Date
        return nil if value.blank?
        guess_date_or_time((value.is_a? Time) ? value : cast_to_time(value))
      end

      def self.cast_to_time(value)
        return value if value.is_a? Time
        time_array = ParseDate.parsedate value
        time_array[0] ||= 2000; time_array[1] ||= 1; time_array[2] ||= 1;
        Time.send(ActiveRecord::Base.default_timezone, *time_array) rescue nil
      end

      def self.guess_date_or_time(value)
        (value.hour == 0 and value.min == 0 and value.sec == 0) ?
        Date.new(value.year, value.month, value.day) : value
      end
    end

    def default_sequence_name(table, column) #:nodoc:
      "#{table}_seq"
    end
    
    def create_table(name, options = {}) #:nodoc:
      super(name, options)
      execute "CREATE SEQUENCE #{name}_seq START WITH 10000" unless options[:id] == false
    end

    def rename_table(name, new_name) #:nodoc:
      execute "RENAME #{name} TO #{new_name}"
      execute "RENAME #{name}_seq TO #{new_name}_seq" rescue nil
    end  

    def drop_table(name, options = {}) #:nodoc:
      super(name)
      execute "DROP SEQUENCE #{name}_seq" rescue nil
    end

    def recreate_database(name)
      tables.each{ |table| drop_table(table) }
    end
    
    def insert(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil) #:nodoc:
      if pk.nil? # Who called us? What does the sql look like? No idea!
        execute sql, name
      elsif id_value # Pre-assigned id
        log(sql, name) { @connection.execute_insert sql,pk }
      else # Assume the sql contains a bind-variable for the id
        id_value = select_one("select #{sequence_name}.nextval id from dual")['id'].to_i
        log(sql, name) { 
          @connection.execute_id_insert(sql,id_value)
        }
      end
      id_value
    end

    def indexes(table, name = nil)
      @connection.indexes(table, name, @connection.connection.meta_data.user_name)
    end
    
    def _execute(sql, name = nil)
        case sql.strip
        when /^(select|show)/i:
          @connection.execute_query(sql)
        else
          @connection.execute_update(sql)
        end
    end
    
    def modify_types(tp)
      tp[:primary_key] = "NUMBER(38) NOT NULL PRIMARY KEY"
      tp[:datetime] = { :name => "DATE" }
      tp[:timestamp] = { :name => "DATE" }
      tp[:time] = { :name => "DATE" }
      tp[:date] = { :name => "DATE" }
      tp
    end

    def add_limit_offset!(sql, options) #:nodoc:
      offset = options[:offset] || 0
      
      if limit = options[:limit]
        sql.replace "select * from (select raw_sql_.*, rownum raw_rnum_ from (#{sql}) raw_sql_ where rownum <= #{offset+limit}) where raw_rnum_ > #{offset}"
      elsif offset > 0
        sql.replace "select * from (select raw_sql_.*, rownum raw_rnum_ from (#{sql}) raw_sql_) where raw_rnum_ > #{offset}"
      end
    end

    def current_database #:nodoc:
      select_one("select sys_context('userenv','db_name') db from dual")["db"]
    end

    def remove_index(table_name, options = {}) #:nodoc:
      execute "DROP INDEX #{index_name(table_name, options)}"
    end

    def change_column_default(table_name, column_name, default) #:nodoc:
      execute "ALTER TABLE #{table_name} MODIFY #{column_name} DEFAULT #{quote(default)}"
    end

    def change_column(table_name, column_name, type, options = {}) #:nodoc:
      change_column_sql = "ALTER TABLE #{table_name} MODIFY #{column_name} #{type_to_sql(type, options[:limit])}"
      add_column_options!(change_column_sql, options)
      execute(change_column_sql)
    end

    def rename_column(table_name, column_name, new_column_name) #:nodoc:
      execute "ALTER TABLE #{table_name} RENAME COLUMN #{column_name} to #{new_column_name}"
    end

    def remove_column(table_name, column_name) #:nodoc:
      execute "ALTER TABLE #{table_name} DROP COLUMN #{column_name}"
    end

    def structure_dump #:nodoc:
      s = select_all("select sequence_name from user_sequences").inject("") do |structure, seq|
        structure << "create sequence #{seq.to_a.first.last};\n\n"
      end

      select_all("select table_name from user_tables").inject(s) do |structure, table|
        ddl = "create table #{table.to_a.first.last} (\n "  
        cols = select_all(%Q{
              select column_name, data_type, data_length, data_precision, data_scale, data_default, nullable
              from user_tab_columns
              where table_name = '#{table.to_a.first.last}'
              order by column_id
            }).map do |row|
          row = row.inject({}) do |h,args| 
            h[args[0].downcase] = args[1]
            h 
          end
          col = "#{row['column_name'].downcase} #{row['data_type'].downcase}"      
          if row['data_type'] =='NUMBER' and !row['data_precision'].nil?
            col << "(#{row['data_precision'].to_i}"
            col << ",#{row['data_scale'].to_i}" if !row['data_scale'].nil?
            col << ')'
          elsif row['data_type'].include?('CHAR')
            col << "(#{row['data_length'].to_i})"  
          end
          col << " default #{row['data_default']}" if !row['data_default'].nil?
          col << ' not null' if row['nullable'] == 'N'
          col
        end
        ddl << cols.join(",\n ")
        ddl << ");\n\n"
        structure << ddl
      end
    end

    def structure_drop #:nodoc:
      s = select_all("select sequence_name from user_sequences").inject("") do |drop, seq|
        drop << "drop sequence #{seq.to_a.first.last};\n\n"
      end

      select_all("select table_name from user_tables").inject(s) do |drop, table|
        drop << "drop table #{table.to_a.first.last} cascade constraints;\n\n"
      end
    end
    
    # QUOTING ==================================================
    #
    # see: abstract/quoting.rb
    
    # camelCase column names need to be quoted; not that anyone using Oracle
    # would really do this, but handling this case means we pass the test...
    def quote_column_name(name) #:nodoc:
      name =~ /[A-Z]/ ? "\"#{name}\"" : name
    end

    def quote_string(string) #:nodoc:
      string.gsub(/'/, "''")
    end
    
    def quote(value, column = nil) #:nodoc:
      if column && column.type == :binary
        if /(.*?)\([0-9]+\)/ =~ column.sql_type
          %Q{empty_#{ $1 }()}
        else
          %Q{empty_#{ column.sql_type rescue 'blob' }()}
        end
      else
        if column && column.type == :primary_key
          return value.to_s
        end
        case value
        when String, ActiveSupport::Multibyte::Chars     : %Q{'#{quote_string(value)}'}
        when NilClass   : 'null'
        when TrueClass  : '1'
        when FalseClass : '0'
        when Numeric    : value.to_s
        when Date, Time : %Q{TIMESTAMP'#{value.strftime("%Y-%m-%d %H:%M:%S")}'}
        else              %Q{'#{quote_string(value.to_yaml)}'}
        end
      end
    end
    
    private
    
    def select(sql, name = nil)
      records = execute(sql, name)
      records.map do |col|
          col.delete('raw_rnum_')
          col       
      end
      records
    end
  end
end
