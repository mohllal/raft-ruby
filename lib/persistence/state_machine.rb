require_relative 'file_storage'
require_relative '../config'

# Simple key-value state machine for Raft demo
#
# This implements the application logic, a basic key-value store
# that processes committed log entries and persists its state.
#
# Note: This is simplified for demo purposes. A production Raft
# implementation would include things like: Snapshots for log compaction,
# concurrent read handling, more sophisticated command processing, etc...

module Raft
  class StateMachine
    def initialize(node_id)
      @node_id = node_id
      @logger = Config.logger_for(self.class)

      # The actual key-value store
      @store = {}

      # Storage for persistence
      storage_path = File.join(Config::DATA_DIR, node_id.to_s, Config::STATE_FILE)
      @storage = FileStorage.new(storage_path)

      # Load existing state
      load_state
      logger.info "State machine for node #{node_id} initialized with #{@store.size} entries"
    end

    # Apply a command to the state machine
    # This is called when a log entry is committed
    def apply(command)
      return { error: 'Invalid command format' } unless command.is_a?(Hash)

      key = command['key'] || command[:key]
      value = command['value'] || command[:value]
      type = command['type'] || command[:type]

      case type
      when 'SET'
        set(key, value)
      when 'GET'
        get(key)
      when 'DELETE'
        delete(key)
      else
        logger.warn "Unknown command type: #{type}"
        { error: "Unknown command type: #{type}" }
      end
    end

    # Get the size of the state machine
    def size
      store.size
    end

    private

    attr_reader :node_id, :logger, :storage, :store

    # Set a key-value pair
    def set(key, value)
      return { error: 'Key cannot be nil' } if key.nil?

      old_value = store[key]
      store[key] = value
      persist_state

      logger.info "SET #{key} = #{value} (was: #{old_value})"
      { success: true, key: key, value: value, old_value: old_value }
    end

    # Get a value by key
    def get(key)
      value = store[key]

      logger.info "GET #{key} => #{value}"
      { success: true, key: key, value: value }
    end

    # Delete a key
    def delete(key)
      value = store.delete(key)
      persist_state

      logger.info "DELETE #{key} (was: #{value})"
      { success: true, key: key, deleted_value: value }
    end

    # Load state from disk
    def load_state
      data = storage.read
      @store = data if data.is_a?(Hash)
      logger.debug "Loaded #{@store.size} entries from disk"
    rescue StandardError => e
      logger.error "Failed to load state: #{e.message}"
      @store = {}
    end

    # Persist state to disk
    def persist_state
      storage.write(store)
      logger.debug "Persisted #{store.size} entries to disk"
    rescue StandardError => e
      logger.error "Failed to persist state: #{e.message}"
    end
  end
end
