module ActiveRecord
  module Associations
    class AssociationScope #:nodoc:
      def add_constraints(scope, owner, assoc_klass, refl, tracker)
        # Shopmatic: handle 'has_many': add owner multi tenant id 
        if owner.class&.multi_tenant? && assoc_klass&.multi_tenant?
          scope = scope.where(tenant_id: owner.tenant_id)
        end
        # ===
        chain = refl.chain
        scope_chain = refl.scope_chain

        tables = construct_tables(chain, assoc_klass, refl, tracker)

        owner_reflection = chain.last
        table = tables.last
        scope = last_chain_scope(scope, table, owner_reflection, owner, tracker, assoc_klass)

        chain.each_with_index do |reflection, i|
          table, foreign_table = tables.shift, tables.first

          unless reflection == chain.last
            next_reflection = chain[i + 1]
            scope = next_chain_scope(scope, table, reflection, tracker, assoc_klass, foreign_table, next_reflection)
          end

          is_first_chain = i == 0
          klass = is_first_chain ? assoc_klass : reflection.klass

          # Exclude the scope of the association itself, because that
          # was already merged in the #scope method.
          scope_chain[i].each do |scope_chain_item|
            item  = eval_scope(klass, scope_chain_item, owner)

            if scope_chain_item == refl.scope
              scope.merge! item.except(:where, :includes, :bind)
            end

            if is_first_chain
              scope.includes! item.includes_values
            end

            scope.unscope!(*item.unscope_values)
            scope.where_values += item.where_values
            scope.bind_values  += item.bind_values
            scope.order_values |= item.order_values
          end
        end

        scope
      end
    end
  end
end