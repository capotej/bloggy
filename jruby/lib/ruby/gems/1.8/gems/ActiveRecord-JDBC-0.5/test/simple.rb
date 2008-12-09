module MigrationSetup
  def setup
    CreateEntries.up
    CreateAutoIds.up

    @connection = ActiveRecord::Base.connection
  end

  def teardown
    CreateEntries.down
    CreateAutoIds.down
  end
end

module FixtureSetup
  include MigrationSetup
  def setup
    super
    @title = "First post!"
    @content = "Hello from JRuby on Rails!"
    @new_title = "First post updated title"
    @rating = 205
    Entry.create :title => @title, :content => @content, :rating => @rating
  end
end

module SimpleTestMethods
  include FixtureSetup

  def test_entries_created
    assert ActiveRecord::Base.connection.tables.find{|t| t =~ /^entries$/i}, "entries not created"
  end

  def test_entries_empty
    Entry.delete_all
    assert_equal 0, Entry.count
  end

  def test_create_new_entry
    Entry.delete_all

    post = Entry.new
    post.title = @title
    post.content = @content
    post.rating = @rating
    post.save

    assert_equal 1, Entry.count
  end

  def test_create_partial_new_entry
    new_entry = Entry.create(:title => "Blah")
    new_entry2 = Entry.create(:title => "Bloh")
  end

  def test_find_and_update_entry
    post = Entry.find(:first)
    assert_equal @title, post.title
    assert_equal @content, post.content
    assert_equal @rating, post.rating

    post.title = @new_title
    post.save

    post = Entry.find(:first)
    assert_equal @new_title, post.title
  end

  def test_destroy_entry
    prev_count = Entry.count
    post = Entry.find(:first)
    post.destroy

    assert_equal prev_count - 1, Entry.count
  end

  def test_indexes
    # Only test indexes if we have implemented it for the particular adapter
    if @connection.respond_to?(:indexes)
      indexes = @connection.indexes(:entries)
      assert_equal(0, indexes.size)
        
      index_name = "entries_index"
      @connection.add_index(:entries, :updated_on, :name => index_name)
        
      indexes = @connection.indexes(:entries)
      assert_equal(1, indexes.size)
      assert_equal "entries", indexes.first.table
      assert_equal index_name, indexes.first.name
      assert !indexes.first.unique
      assert_equal ["updated_on"], indexes.first.columns
    end
  end

  def test_dumping_schema
    require 'active_record/schema_dumper'
    @connection.add_index :entries, :title
    StringIO.open do |io|
      ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, io)
      assert_match(/add_index "entries",/, io.string)
    end
    @connection.remove_index :entries, :title

  end

  def test_nil_values
    test = AutoId.create('value' => '')
    assert_nil AutoId.find(test.id).value
  end

  def test_invalid
    e = Entry.new(:title => @title, :content => @content, :rating => ' ')
    p e.valid?
  end

end

module MultibyteTestMethods
  include MigrationSetup

  def setup
    super
    config = ActiveRecord::Base.connection.config
    props = java.util.Properties.new
    props.setProperty("user", config[:username])
    props.setProperty("password", config[:password])
    @java_con = java.sql.DriverManager.getConnection(config[:url], props)
    @java_con.setAutoCommit(true)
  end

  def teardown
    @java_con.close
    super
  end

  def test_select_multibyte_string
    @java_con.createStatement().execute("insert into entries (title, content) values ('テスト', '本文')")
    entry = Entry.find(:first)
    assert_equal "テスト", entry.title
    assert_equal "本文", entry.content
    assert_equal entry, Entry.find_by_title("テスト")
  end

  def test_update_multibyte_string
    Entry.create!(:title => "テスト", :content => "本文")
    rs = @java_con.createStatement().executeQuery("select title, content from entries")
    assert rs.next
    assert_equal "テスト", rs.getString(1)
    assert_equal "本文", rs.getString(2)
  end
end
