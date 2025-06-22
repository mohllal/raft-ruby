require 'drb'
require 'timeout'
require_relative '../config'
require_relative '../models'

# Remote node wrapper for DRb client connections
#
# This class provides a wrapper for DRb client connections to remote nodes.
# It allows for calling methods on remote nodes with a timeout and retry logic.
#
# @param node_id [String] The ID of the remote node
# @param port [Integer] The port of the remote node
# @param timeout [Float] The timeout for the remote call
# @param retries [Integer] The number of retries for the remote call

module Raft
  class RemoteNode
    def initialize(node_id, port)
      @node_id = node_id
      @port = port
      @timeout = Config::RPC_TIMEOUT
      @retries = Config::RPC_RETRIES
      @uri = "druby://localhost:#{port}"
      @remote_node = DRbObject.new_with_uri(uri)
      @logger = Config.logger_for(self.class)

      DRb.start_service unless DRb.primary_server
    end

    attr_reader :node_id, :uri, :remote_node

    # Call a remote method
    def call_remote(method_name, *args)
      attempt = 1

      while attempt <= retries
        begin
          logger.debug "Calling #{method_name} on #{node_id} (attempt #{attempt}/#{retries})"

          result = Timeout.timeout(timeout) do
            remote_node.send(method_name, *args)
          end

          logger.debug "Successfully called #{method_name} on #{node_id}"
          return result
        rescue Timeout::Error
          logger.debug "Timeout calling #{method_name} on #{node_id} (attempt #{attempt}/#{retries})"
          attempt += 1
          sleep(0.1) if attempt <= retries
        rescue DRb::DRbConnError, Errno::ECONNREFUSED => e
          logger.debug "Connection error #{method_name} on #{node_id}: #{e.message} (attempt #{attempt}/#{retries})"
          attempt += 1
          sleep(0.1) if attempt <= retries
        rescue StandardError => e
          logger.error "Error calling #{method_name} on #{node_id}: #{e.message}"
          raise
        end
      end

      logger.debug "Failed to call #{method_name} on #{node_id} after #{retries} attempts"
      raise DRb::DRbConnError, "Failed to connect to #{node_id} after #{retries} attempts"
    end

    # Request vote from a remote node
    def request_vote(request)
      logger.info "→ Requesting vote from #{node_id} (term #{request.term})"

      response = call_remote(:request_vote, request)

      logger.info "← Vote response from #{node_id}: #{response}"
      response
    end

    # Send append entries to a remote node
    def append_entries(request)
      entry_count = request.log_entries&.length || 0
      logger.info "→ Sending append_entries to #{node_id} (term #{request.term}, #{entry_count} entries)"

      response = call_remote(:append_entries, request)

      logger.info "← AppendEntries response from #{node_id}: #{response}"
      response
    end

    # Check if a remote node is reachable
    def ping
      logger.info "→ Sending ping to #{node_id}"

      response = call_remote(:ping)

      logger.info "← Ping response from #{node_id}: #{response}"
      response
    end

    private

    attr_reader :port, :timeout, :retries, :logger
  end
end
