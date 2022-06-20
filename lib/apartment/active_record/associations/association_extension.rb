module ActiveRecord
  module Associations
    class Association #:nodoc:
      # Can be overridden (i.e. in ThroughAssociation) to merge in other scopes (i.e. the
      # through association's scope)
      def target_scope
        # Shopmatic: monkey patch
        # Get tenant_id
        tenant_id = nil
        begin
          if owner.is_a?(Apartment.partition_class)
            tenant_id = owner.id
          elsif owner.respond_to?(:tenant_id)
            tenant_id = owner.tenant_id
          end
        rescue => e
          expected_owner = owner rescue nil
          Rails.logger.error "[Apartment/Single Schema] Fail to get tenant_id from owner: #{expected_owner} !: #{e.message}"
          e.backtrace.each do |line|
            Rails.logger.error line
          end
        end
        if tenant_id
          ret = nil
          Apartment::Tenant.switch(tenant_id) do
            ret = AssociationRelation.create(klass, self).merge!(klass.all)
          end
          ret
        else
          AssociationRelation.create(klass, self).merge!(klass.all)
        end
      end
    end
  end
end