module ActiveRecord
  module Associations # :nodoc:
    def association(name) #:nodoc:
      association = association_instance_get(name)

      if association.nil?
        # Shopmatic: monkey patch
        if tenant_id = get_tenant_id
          Apartment::Tenant.switch(tenant_id) do
            association = fetch_association(name)
          end
        else
          association = fetch_association(name)
        end
      end

      association
    end

    def fetch_association(name)
      raise AssociationNotFoundError.new(self, name) unless reflection = self.class._reflect_on_association(name)
      association = reflection.association_class.new(self, reflection)
      association_instance_set(name, association)
      association
    end

    def get_tenant_id
      return self.id if self.is_a?(Apartment.partition_class)
      return self.tenant_id if self.respond_to?(:tenant_id)
      return nil
    end
  end
end
