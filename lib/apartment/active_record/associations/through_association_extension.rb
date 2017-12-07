module ActiveRecord
  # = Active Record Through Association
  module Associations
    module ThroughAssociation #:nodoc:
      protected

      # We merge in these scopes for two reasons:
      #
      #   1. To get the default_scope conditions for any of the other reflections in the chain
      #   2. To get the type conditions for any STI models in the chain
      def target_scope
        scope = super
        reflection.chain.drop(1).each do |reflection|
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
          
          relation = nil
          if tenant_id
            Apartment::Tenant.switch(tenant_id) do
              relation = reflection.klass.all
            end
          else
            relation = reflection.klass.all
          end
          # end of patch
          scope.merge!(
            relation.except(:select, :create_with, :includes, :preload, :joins, :eager_load)
          )
        end
        scope
      end
    end
  end
end