require 'request_store'

module Apartment
  module ActiveJobExtension

    extend ActiveSupport::Concern

    included do
      around_perform do |job, block|
        if Apartment.use_single_schema
          RequestStore.push_state!
          block.call
          RequestStore.pop_state!
        else
          block.call
        end
      end
    end
  end
end





if defined?(ActiveJob::Base)
  ActiveJob::Base.include(Apartment::ActiveJobExtension)
end