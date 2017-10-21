module ActiveRecord
  # = Active Record Persistence
  module Persistence
    def reload(options = nil)
      clear_aggregation_cache
      clear_association_cache
      self.class.connection.clear_query_cache

      # Shopmatic: wrap the find in the tenant switch, or use the current tenant
      if self.class.multi_tenant?
        Apartment::Tenant.switch(tenant_id || Apartment::Tenant.current) do
          reload_load_attributes(options)
        end
      else
        # Original one
        reload_load_attributes(options)
      end

      @new_record = false
      self
    end

    def reload_load_attributes(options)
      fresh_object =
        if options && options[:lock]
          self.class.unscoped { self.class.lock(options[:lock]).find(id) }
        else
          self.class.unscoped { self.class.find(id) }
        end
      
      @attributes = fresh_object.instance_variable_get('@attributes')
    end
  end
end
