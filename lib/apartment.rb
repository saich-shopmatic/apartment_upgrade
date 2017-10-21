require 'apartment/railtie' if defined?(Rails)
require 'active_support/core_ext/object/blank'
require 'forwardable'
require 'active_record'
require 'apartment/tenant'
require 'apartment/deprecation'
require 'parallel'
require 'apartment/model_extension'
require 'apartment/migrations'
require 'tsort'
require 'apartment/activerecord_multi_tenant_patch'
require 'apartment/active_record/core_extension'
require 'apartment/active_record/reflection_extension'
require 'apartment/active_record/persistence_extension'
require 'apartment/active_record/associations/association_scope_extension'


module Apartment
  class ForeignKeyDependency
    include TSort
  
    def initialize
      @requirements = Hash.new{|h,k| h[k] = []}
    end
  
    def add_requirement(name, *requirement_dependencies)
      @requirements[name] = requirement_dependencies
    end
  
    def tsort_each_node(&block)
      @requirements.each_key(&block)
    end
  
    def tsort_each_child(name, &block)
      @requirements[name].each(&block) if @requirements.has_key?(name)
    end  
  end

  class << self

    extend Forwardable

    ACCESSOR_METHODS  = [:use_schemas, :use_sql, :seed_after_create, :prepend_environment, :append_environment, :with_multi_server_setup, :use_parallel_tenant_task, :use_single_schema, :single_schema_default_tenant ]
    WRITER_METHODS    = [:tenant_names, :database_schema_file, :excluded_models, :default_schema, :persistent_schemas, :connection_class, :tld_length, :db_migrate_tenants, :seed_data_file, :num_parallel_in_processes, :multi_tenant_models, :partition_model, :compute_tenant_id_method, :compute_tenant_name_method, :single_schema_partition_field]

    attr_accessor(*ACCESSOR_METHODS)
    attr_writer(*WRITER_METHODS)

    def_delegators :connection_class, :connection, :connection_config, :establish_connection

    # configure apartment with available options
    def configure
      yield self if block_given?
    end

    def tenant_names
      extract_tenant_config.keys.map(&:to_s)
    end

    def tenants_with_config
      extract_tenant_config
    end

    def db_config_for(tenant)
      (tenants_with_config[tenant] || connection_config).with_indifferent_access
    end

    # Whether or not db:migrate should also migrate tenants
    # defaults to true
    def db_migrate_tenants
      return @db_migrate_tenants if defined?(@db_migrate_tenants)

      @db_migrate_tenants = true
    end

    # Default to empty array
    def excluded_models
      @excluded_models || []
    end

    def default_schema
      @default_schema || "public" # TODO 'public' is postgres specific
    end
    alias :default_tenant :default_schema
    alias :default_tenant= :default_schema=

    def persistent_schemas
      @persistent_schemas || []
    end

    def connection_class
      @connection_class || ActiveRecord::Base
    end

    def database_schema_file
      return @database_schema_file if defined?(@database_schema_file)

      @database_schema_file = Rails.root.join('db', 'schema.rb')
    end

    def seed_data_file
      return @seed_data_file if defined?(@seed_data_file)

      @seed_data_file = "#{Rails.root}/db/seeds.rb"
    end

    def tld_length
      @tld_length || 1
    end

    # Reset all the config for Apartment
    def reset
      (ACCESSOR_METHODS + WRITER_METHODS).each{|method| remove_instance_variable(:"@#{method}") if instance_variable_defined?(:"@#{method}") }
    end

    def database_names
      Apartment::Deprecation.warn "[Deprecation Warning] `database_names` is now deprecated, please use `tenant_names`"
      tenant_names
    end

    def database_names=(names)
      Apartment::Deprecation.warn "[Deprecation Warning] `database_names=` is now deprecated, please use `tenant_names=`"
      self.tenant_names=(names)
    end

    def use_postgres_schemas
      Apartment::Deprecation.warn "[Deprecation Warning] `use_postgresql_schemas` is now deprecated, please use `use_schemas`"
      use_schemas
    end

    def use_postgres_schemas=(to_use_or_not_to_use)
      Apartment::Deprecation.warn "[Deprecation Warning] `use_postgresql_schemas=` is now deprecated, please use `use_schemas=`"
      self.use_schemas = to_use_or_not_to_use
    end

    def num_parallel_in_processes
      return @num_parallel_in_processes if defined?(@num_parallel_in_processes)

      @num_parallel_in_processes = [1,ActiveRecord::Base.connection_pool.size - 2].max
    end

    def multi_tenant_models
      @multi_tenant_models ||= []
    end

    def multi_tenant_model_classes
      @multi_tenant_model_classes ||= self.multi_tenant_models.map(&:constantize)
    end

    def multi_tenant_table_names
      @multi_tenant_table_names ||= self.multi_tenant_model_classes.map(&:table_name)
    end

    def multi_tenant_table_name_to_class(table_name)
      if @multi_tenant_table_name_to_class_map.nil?
        @multi_tenant_table_name_to_class_map = {}
        self.multi_tenant_model_classes.each do |klass|
          @multi_tenant_table_name_to_class_map[klass.table_name] = klass
        end
      end
      @multi_tenant_table_name_to_class_map[table_name]
    end

    def partition_model
      raise RuntimeError, "No partition_model defined" unless @partition_model
      @partition_model
    end

    def partition_class
      @partition_class ||= self.partition_model.constantize
    end

    def compute_tenant_id_method
      @compute_tenant_id_method ||= proc do |tenant_name|
        if tenant_name.nil? || tenant_name == "public"
          0
        else
          tenant_name.to_i
        end
      end
    end

    def compute_tenant_name_method
      @compute_tenant_name_method ||= proc do |tenant_id|
        if tenant_id.nil? || tenant_id == 0
          "public"
        else
          tenant_id.to_s
        end
      end
    end

    def record_foreign_key_dependency(from_table, to_table)
      @fk_dependency = ForeignKeyDependency.new if @fk_dependency.nil?
      @fk_dependency.add_requirement(from_table, to_table)
    end

    def foreign_key_tsort
      return [] if @fk_dependency.nil?
      @fk_dependency.tsort
    end

    # Meaningful for non-partition model
    def single_schema_partition_field
      @single_schema_partition_field ||= "#{self.partition_model.underscore}_id".to_sym
    end

    def sanity_check
      registered = registered_multi_tenant_model.map(&:to_s).sort
      expected = multi_tenant_models.sort
      puts "Expect: #{expected}"
      puts "Registered: #{registered}"
      puts "Same: #{expected == registered}"
    end

    def registered_multi_tenant_model
      @registered_multi_tenant_model ||= []
    end

    def register_multi_tenant_model(klass)
      registered_multi_tenant_model << klass
    end

    def extract_tenant_config
      return {} unless @tenant_names
      values = @tenant_names.respond_to?(:call) ? @tenant_names.call : @tenant_names
      unless values.is_a? Hash
        values = values.each_with_object({}) do |tenant, hash|
          hash[tenant] = connection_config
        end
      end
      values.with_indifferent_access
    rescue ActiveRecord::StatementInvalid
      {}
    end

    def without_multi_tenant(*args, &block)
      MultiTenant.without_multi_tenant(*args, &block)
    end
  end

  # Exceptions
  ApartmentError = Class.new(StandardError)

  # Raised when apartment cannot find the adapter specified in <tt>config/database.yml</tt>
  AdapterNotFound = Class.new(ApartmentError)

  # Tenant specified is unknown
  TenantNotFound = Class.new(ApartmentError)

  # The Tenant attempting to be created already exists
  TenantExists = Class.new(ApartmentError)
end
