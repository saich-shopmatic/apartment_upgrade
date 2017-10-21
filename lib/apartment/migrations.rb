module ActiveRecord
  module ConnectionAdapters # :nodoc:
    module SchemaStatements
      alias :shopmatic_orig_create_table :create_table
      def create_table(table_name, options = {}, &block)
        ret = shopmatic_orig_create_table(table_name, options, &block)
        # single_schema-specific
        if Apartment.use_single_schema
          # find the corresponding class_name
          klass = nil
          Apartment.multi_tenant_model_classes.each do |testing_klass|
            if testing_klass.table_name == table_name
              klass = testing_klass
              break
            end
          end
          if klass # This class is a multi-tenant class
            # check whether this table need to change primary key
            if klass != Apartment.partition_model.constantize            
              # Not the partition model, need to change key
              Rails.logger.info "[Apartment/SingleSchema] Changing primary key for #{table_name}"
              execute "ALTER TABLE #{table_name} DROP CONSTRAINT #{table_name}_pkey"
              execute "ALTER TABLE #{table_name} ADD PRIMARY KEY(id, \"#{Apartment.single_schema_partition_field}\")"
            end
          end
        end
        ret
      end
    end
  end
end

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

module ActiveRecord
  module ConnectionAdapters
    class AbstractAdapter
      class SchemaCreation # :nodoc:
        # Overrite the original method in ActiveRecord 4.2.7.1
        alias :shopmatic_orig_visit_AddForeignKey :visit_AddForeignKey
        def visit_AddForeignKey(o)
          if Apartment.use_single_schema
            # check if both from_table and to_table is  multi_tenant
            from_table_class = Apartment.multi_tenant_table_name_to_class(o.from_table)
            to_table_class = Apartment.multi_tenant_table_name_to_class(o.to_table)
            if from_table_class && to_table_class
              Rails.logger.info "[Apartment/SingleSchema] create composite foreign key for #{o.from_table}/#{o.to_table} with paritition field #{from_table_class.partition_field}/#{to_table_class.partition_field}"
              sql = <<-SQL.strip_heredoc
                ADD CONSTRAINT #{quote_column_name(o.name)}
                FOREIGN KEY (#{quote_column_name(o.column)},#{quote_column_name(from_table_class.partition_field)})
                  REFERENCES #{quote_table_name(o.to_table)} (#{quote_column_name(o.primary_key)},#{quote_column_name(to_table_class.partition_field)})
              SQL
              sql << " #{action_sql('DELETE', o.on_delete)}" if o.on_delete
              sql << " #{action_sql('UPDATE', o.on_update)}" if o.on_update
              sql
            else
              # Non multi-tenant table
              Rails.logger.info "[Apartment/SingleSchema] create original foreign key for #{o.from_table}/#{o.to_table}"
              shopmatic_orig_visit_AddForeignKey(o)
            end
          else
            # Not single_schema
            shopmatic_orig_visit_AddForeignKey(o)
          end
        end
      end
    end
  end
end