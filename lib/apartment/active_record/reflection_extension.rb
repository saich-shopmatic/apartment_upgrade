
if defined?(ActiveRecord::Reflection)
  module ActiveRecord
    # = Active Record Reflection
    module Reflection # :nodoc:
      class AssociationReflection

        def current_tenant_key(owner)
          if owner.is_a?(Apartment.partition_class)
            Apartment.compute_tenant_name_method.call(owner.id)
          elsif owner.respond_to?(:tenant_id)
            Apartment.compute_tenant_name_method.call(owner.tenant_id)
          else
            Apartment::Tenant.tenant_key
          end          
        end

        def association_scope_cache(conn, owner)
          key = conn.prepared_statements
          if polymorphic?
            key = [key, owner._read_attribute(@foreign_type)]
          end
          # Shopmatic: monkey patch
          tenant_key = current_tenant_key(owner)
          if key.is_a?(Array)
            key << tenant_key
          else
            key = [key, tenant_key]
          end
          @association_scope_cache[key] ||= @scope_lock.synchronize {
            @association_scope_cache[key] ||= yield
          }
        end
      end
    end
  end
end