module ArHelpers
  def execute_simple_string_query(query)
    ActiveRecord::Base.connection.execute(query).first[0]
  end

  def load_test_value(id)
    execute_simple_string_query( "select #{test_attr.to_s} from #{entity_table} where id = #{id}")
  end
end
