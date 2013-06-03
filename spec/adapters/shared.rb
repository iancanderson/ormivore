module Helpers
  def execute_simple_int_query(query)
    execute_simple_string_query(query).to_i
  end

  def execute_simple_string_query(query)
    ActiveRecord::Base.connection.execute(query).first[0]
  end
end

shared_examples_for 'an adapter' do
  include Helpers

  let(:test_value) { 'Foo' }

  subject { described_class.new(App::NoopConverter.new) }

  it 'responds to find' do
    subject.should respond_to(:find)
  end

  describe '#find' do
    context 'when conditions points to non-existing entity' do
      it 'should raise error' do
        expect {
          subject.find(id: 123456789)
        }.to raise_error ORMivore::RecordNotFound
      end
    end

    context 'when id points to existing entity' do
      it 'should return proper entity attrs' do
        entity = create_entity
        data = subject.find(id: entity.id)
        data.should_not be_nil
        data[test_attr].should == entity.public_send(test_attr)
      end
    end
  end

  describe '#create' do
    context 'when attempting to create record with id that is already present in database' do
      it 'raises error' do
        expect {
          subject.create(subject.create(attrs))
        }.to raise_error ActiveRecord::StatementInvalid
      end
    end

    context 'when record does not have an id' do
      it 'returns back attributes including new id' do
        data = subject.create(attrs)
        data.should include(attrs)
        data[:id].should be_kind_of(Integer)
      end

      it 'inserts record in database' do
        data = subject.create(attrs)

        new_value = execute_simple_string_query( "select #{test_attr.to_s} from #{entity_table} where id = #{data[:id]}")
        new_value.should == test_value
      end
    end
  end

  describe '#update' do
    context 'when record did not exist' do
      it 'returns 0 update count' do
        create_entity
        subject.update(attrs, id: 123).should == 0
      end
    end

    context 'when record existed' do
      it 'returns update count 1' do
        entity = create_entity

        subject.update(attrs, id: entity.id).should == 1
      end

      it 'updates record attributes' do
        entity = create_entity

        subject.update(attrs, id: entity.id)

        new_value = execute_simple_string_query( "select #{test_attr.to_s} from #{entity_table} where id = #{entity.id}")
        new_value.should == test_value
      end
    end

    context 'when 2 matching records existed' do
      it 'returns update count 2' do
        entity_ids = []
        entity_ids << create_entity.id
        entity_ids << create_entity.id

        subject.update(attrs, id: entity_ids).should == 2
      end
    end

    context 'when conditions to update are not quite right' do
      it 'should raise an error' do
        expect {
          subject.update(attrs, foo: 'bar')
        }.to raise_error ActiveRecord::StatementInvalid
      end
    end
  end
end