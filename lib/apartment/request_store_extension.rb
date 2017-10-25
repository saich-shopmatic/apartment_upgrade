require 'request_store'

module RequestStore
  def self.push_state!
    self.backup_stack.push(active: self.active?, store: self.store)
    # Clear previous state
    Thread.current[:request_store_active] = false
    Thread.current[:request_store] = {}    
  end

  def self.pop_state!
    if last_state = self.backup_stack.pop
      Thread.current[:request_store_active] = last_state[:active]
      Thread.current[:request_store] =  last_state[:store]
    end
  end

  def self.backup_stack
    Thread.current[:request_store_backup_stack] ||= []
  end
end
