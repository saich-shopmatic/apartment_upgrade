module ActiveRecord
  module Associations
    class AssociationScope #:nodoc:

      def add_constraints(scope, owner, chain)
        scope = last_chain_scope(scope, chain.last, owner)

        chain.each_cons(2) do |reflection, next_reflection|
          scope = next_chain_scope(scope, reflection, next_reflection)
        end

        chain_head = chain.first
        chain.reverse_each do |reflection|
          # Exclude the scope of the association itself, because that
          # was already merged in the #scope method.
          reflection.constraints.each do |scope_chain_item|
            item = eval_scope(reflection, scope_chain_item, owner)

            if scope_chain_item == chain_head.scope
              scope.merge! item.except(:where, :includes, :unscope, :order)
            end

            reflection.all_includes do
              scope.includes! item.includes_values
            end

            scope.unscope!(*item.unscope_values)
            scope.where_clause += item.where_clause
            scope.order_values = item.order_values | scope.order_values
          end
        end
        scope
      end
    end
  end
end