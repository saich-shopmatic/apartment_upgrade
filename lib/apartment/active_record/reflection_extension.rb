
if defined?(ActiveRecord::Reflection)
  module ActiveRecord
    # = Active Record Reflection
    module Reflection # :nodoc:
      class AssociationReflection
        def association_scope_cache(conn, owner)
          key = conn.prepared_statements
          if polymorphic?
            key = [key, owner._read_attribute(@foreign_type)]
          end
          # Shopmatic: monkey patch
          tenant_key = Apartment::Tenant.tenant_key
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