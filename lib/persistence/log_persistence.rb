require_relative 'file_storage'
require_relative '../models'
require_relative '../config'

# Simple persistence for Raft log entries and metadata
#
# This class persists the log entries and metadata for a Raft node.

module Raft
  class LogPersistence
    def initialize(node_id)
      @node_id = node_id

      @log_storage = FileStorage.new(File.join(Config::LOG_DIR, node_id.to_s, Config::LOG_FILE))
      @metadata_storage = FileStorage.new(File.join(Config::LOG_DIR, node_id.to_s, Config::METADATA_FILE))

      @logger = Config.logger_for(self.class)
      logger.info "Log persistence for node #{node_id} initialized"
    end

    # Save log entries
    def save_log(entries)
      log_data = entries.map(&:to_h)

      log_storage.write(log_data)
      logger.debug "Saved #{entries.length} log entries"
    end

    # Load log entries
    def load_log
      data = log_storage.read
      return [] unless data.is_a?(Array)

      entries = data.map { |entry_data| Models::LogEntry.from_hash(entry_data) }
      entries.compact

      logger.info "Loaded #{entries.length} log entries"
      entries
    rescue StandardError => e
      logger.error "Failed to load log: #{e.message}"
      []
    end

    # Save metadata
    def save_metadata(metadata)
      metadata.update_timestamp

      metadata_storage.write(metadata.to_h)
      logger.debug "Saved metadata: #{metadata}"
    end

    # Load metadata
    def load_metadata
      data = metadata_storage.read
      Models::Metadata.from_hash(data)
    rescue StandardError => e
      logger.error "Failed to load metadata: #{e.message}"
      Models::Metadata.from_hash({})
    end

    private

    attr_reader :node_id, :log_storage, :metadata_storage, :logger
  end
end
