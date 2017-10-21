require 'request_store'

module Apartment

  module ExcludeTenantIdFromJson
    def as_json(options = {})
      super(options.merge({ except: [:tenant_id] }))
    end
  end

  module CitusModelExtension
  
    extend ActiveSupport::Concern
    
    CITUS_DEFAULT_ID_FIELD = 'id'.freeze

    included do
      def fix_tenant_id
        if self.class.force_save_current_tenant
          if self.class.partition_field != CITUS_DEFAULT_ID_FIELD
            current_tenant_id = MultiTenant.current_tenant || 0
            model_tenant_id = self[self.class.partition_field]
            if model_tenant_id != current_tenant_id
              Rails.logger.info "[Apartment/Citus] Fix tenant id for #{self}: #{model_tenant_id}->#{current_tenant_id}"
              self[self.class.partition_field] = current_tenant_id
            end
          end
        end
      end
    end


    module ClassMethods
      def force_save_current_tenant
        RequestStore.store[[self, :force_save_current_tenant]]
      end

      def force_save_current_tenant=(val)
        RequestStore.store[[self, :force_save_current_tenant]] = val
      end

      def multi_tenant?
        false
      end

      def use_citus_multi_tenant
        if Apartment.use_citus
          if !table_name
            byebug
          end
          include Apartment::ExcludeTenantIdFromJson
          multi_tenant(Apartment.partition_model.underscore.to_sym, partition_key: Apartment.citus_partition_field)
          before_save :fix_tenant_id
          Apartment.register_multi_tenant_model(self)
          # Define/overwrite class methods for multi-tenanted model
          class << self

            def multi_tenant?
              true
            end

            def scoped_by_citus_multi_tenant
              true
            end

            def is_partition_model?
              @is_partition_model ||= self == Apartment.partition_model.constantize
            end
      
            def partition_field
              @partition_field ||=  is_partition_model? ? CITUS_DEFAULT_ID_FIELD : Apartment.citus_partition_field
            end
          end
        end
      end
    end

  end
end

if defined?(ActiveRecord::Base)
  ActiveRecord::Base.include(Apartment::CitusModelExtension)
end