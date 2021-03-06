# TODO ArAdapter is really ugly; replace it with some simple Sql adapter without AR 'goodness'
module ORMivore
  module ArAdapter
    module ClassMethods
      attr_reader :default_converter_class
      attr_reader :table_name

      def ar_class
        finalize
        self::ArRecord
      end

      private
      attr_writer :default_converter_class
      attr_writer :table_name

      def expand_on_create(&block)
        @expand_on_create = block
      end

      def finalize
        unless @finalized
          @finalized = true

          file, line = caller.first.split(':', 2)
          line = line.to_i

          module_eval(<<-EOS, file, line - 1)
            class ArRecord < ActiveRecord::Base
              self.table_name = '#{table_name}'
              self.inheritance_column = :_type_disabled
              def attributes_protected_by_default; []; end
            end
          EOS
        end
      end
    end

    def self.included(base)
      base.extend(ClassMethods)
    end

    def initialize(converter = nil)
      @converter = converter || self.class.default_converter_class.new
    end

    def find(conditions, attributes_to_load, options = {})
      order = options.fetch(:order, {})

      ar_class.all(
        select: converter.attributes_list_to_storage(attributes_to_load),
        conditions: conditions,
        order: order_by_clause(order)
      ).map { |r| entity_attributes(r) }
    end

    def create(attrs)
      record = ar_class.create!(
        extend_with_defaults(
          converter.to_storage(attrs))) { |o| o.id = attrs[:id] }
       attrs.merge(id: record.id)
    rescue ActiveRecord::ActiveRecordError => e
      raise StorageError.new(e)
    end

    def update(attrs, conditions)
      ar_class.update_all(converter.to_storage(attrs), conditions)
    rescue ActiveRecord::ActiveRecordError => e
      raise StorageError.new(e)
    end

    private

    attr_reader :converter

    def extend_with_defaults(attrs)
      expansion = self.class.instance_variable_get(:@expand_on_create)
      if expansion
        attrs.merge(expansion.call(attrs))
      else
        attrs
      end
    end

    def order_by_clause(order)
      return '' if order.empty?

      order.map { |k, v|
        direction =
          case v
          when :ascending
            'asc'
          when :descending
            'desc'
          else
            raise BadArgumentError, "Order direction #{v} is invalid"
          end

        "#{k} #{direction}"
      }.join(', ')
    end

    def ar_class
      self.class.ar_class
    end

    def entity_attributes(record)
      converter.from_storage(record.attributes.symbolize_keys)
    end
  end
end
