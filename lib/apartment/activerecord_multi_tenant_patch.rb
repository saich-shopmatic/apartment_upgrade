require 'activerecord-multi-tenant'

module MultiTenant
  class << self
    alias :orig_current_tenant :current_tenant
    def current_tenant
      orig_current_tenant || Apartment.compute_tenant_id_method.call(Apartment.single_schema_default_tenant)
    end

    def tenant_klass_defined?(tenant_name)
      false
    end
  end
end