if defined?(ActiveRecord::Core)
  module ActiveRecord
    module Core
      module ClassMethods
        def current_tenant_key
          Apartment::Tenant.tenant_key
        end

        def find(*ids) # :nodoc:          
          # We don't have cache keys for this stuff yet
          return super unless ids.length == 1
          # Allow symbols to super to maintain compatibility for deprecated finders until Rails 5
          return super if ids.first.kind_of?(Symbol)
          return super if block_given? ||
                          primary_key.nil? ||
                          scope_attributes? ||
                          columns_hash.include?(inheritance_column)
                          default_scopes.any? ||
                          current_scope ||
                          columns_hash.include?(inheritance_column) ||
                          ids.first.kind_of?(Array)
  
          id  = ids.first
          return super if StatementCache.unsupported_value?(id)
          if ActiveRecord::Base === id
            id = id.id
            ActiveSupport::Deprecation.warn(<<-MSG.squish)
              You are passing an instance of ActiveRecord::Base to `find`.
              Please pass the id of the object by calling `.id`
            MSG
          end

          key = primary_key

          # Shopmatic: monkey patch here
          if multi_tenant?
            tenant_key = current_tenant_key
            if key.is_a?(Array)
              cache_key = key.clone
              cache_key << tenant_key
            else
              cache_key = [ key, tenant_key]
            end
          else
            cache_key = key
          end

          s = cached_find_by_statement(key) { |params|
            where(key => params.bind).limit(1)
          }
          record = s.execute([id], connection).first
          unless record
            raise RecordNotFound, "Couldn't find #{name} with '#{primary_key}'=#{id}"
          end
          record
        rescue RangeError
          raise RecordNotFound, "Couldn't find #{name} with an out of range value for '#{primary_key}'"
        end
  
        def find_by(*args) # :nodoc:
          return super if current_scope || !(Hash === args.first) || reflect_on_all_aggregations.any?
          return super if default_scopes.any?
  
          hash = args.first
  
          return super if hash.values.any? { |v|
            v.nil? || Array === v || Hash === v
          }
  
          # We can't cache Post.find_by(author: david) ...yet
          return super unless hash.keys.all? { |k| columns_hash.has_key?(k.to_s) }
  
          key  = hash.keys
          # Shopmatic: monkey patch here
          if multi_tenant?
            cache_key = key.clone
            cache_key << current_tenant_key
          else
            cache_key = key
          end
  
          klass = self
          keys = hash.keys
          s = cached_find_by_statement(keys) { |params|
            wheres = keys.each_with_object({}) { |param, o|
              o[param] = params.bind
            }
            where(wheres).limit(1)
          }
          begin
            s.execute(hash.values, connection).first
          rescue TypeError => e
            raise ActiveRecord::StatementInvalid.new(e.message, e)
          rescue RangeError
            nil
          end
        end
      end  
    end
  end
end