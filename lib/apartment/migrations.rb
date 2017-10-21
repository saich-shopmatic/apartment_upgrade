require 'active_record/connection_adapters/postgresql/schema_statements'

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module SchemaStatements
        alias :shopmatic_orig_add_index :add_index
        def add_index(table_name, column_name, options = {}, &block)
          # if table_name is multi-tenant and it has 'unique: true', it's column name must inclide the partition field
          if options[:unique] && klass = Apartment.multi_tenant_table_name_to_class(table_name)
            column_name = [column_name] unless column_name.is_a?(Array)
            column_name.map!(&:to_sym)
            partition_field = klass.partition_field.to_sym
            unless column_name.include?(partition_field)
              column_name << partition_field
              Rails.logger.info "[Apartment/SingleSchema] multi-tenant unique index for #{table_name} changed to #{column_name}"
            end
          end
          shopmatic_orig_add_index(table_name, column_name, options, &block)
        end
      end
    end
  end
end