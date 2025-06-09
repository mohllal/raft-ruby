require_relative 'file_storage'
require_relative '../config'

# State machine for Raft
#
# This class provides a simple state machine for Raft.
# It allows for applying commands to the state machine and persisting the state.
#
# @param node_id [String] The ID of the node

module Raft
  class StateMachine
    def initialize(node_id)
      @node_id = node_id
      @logger = Config.logger_for(self.class)

      storage_path = File.join(Config::DATA_DIR, @node_id, Config::STATE_MACHINE_FILE)
      @storage = FileStorage.new(storage_path)

      @store = Config::PERSISTENCE_ENABLED ? @storage.read : {}

      logger.info "State machine for #{@node_id} initialized with #{@store.size} entries"
    end

    def apply(command)
      case command[:type]
      when 'SET'
        set(command[:key], command[:value])
      when 'GET'
        get(command[:key])
      when 'DELETE'
        delete(command[:key])
      else
        logger.warn "Unknown command type: #{command[:type]}"
        { error: "Unknown command type: #{command[:type]}" }
      end
    end

    def state
      store.dup
    end

    def size
      store.size
    end

    private

    attr_reader :node_id, :logger, :storage, :store

    def set(key, value)
      old_value = store[key]
      store[key] = value
      persist_state
      logger.info "SET #{key} = #{value} (was: #{old_value})"
      { success: true, key: key, value: value, old_value: old_value }
    end

    def get(key)
      value = store[key]
      logger.info "GET #{key} => #{value}"
      { success: true, key: key, value: value }
    end

    def delete(key)
      value = store.delete(key)
      persist_state
      logger.info "DELETE #{key} (was: #{value})"
      { success: true, key: key, deleted_value: value }
    end

    def persist_state
      return unless Config::PERSISTENCE_ENABLED

      storage.write(store)
      logger.debug 'State persisted'
    rescue StandardError => e
      logger.error "Failed to persist state: #{e.message}"
    end
  end
end
