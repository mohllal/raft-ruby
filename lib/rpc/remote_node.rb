require 'drb'
require 'timeout'
require_relative '../config'

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
    def initialize(node_id, port, timeout: nil, retries: 3)
      @node_id = node_id
      @port = port
      @timeout = timeout || Config::REQUEST_TIMEOUT
      @retries = retries
      @uri = "druby://localhost:#{port}"
      @logger = Config.logger_for(self.class)

      DRb.start_service unless DRb.primary_server
    end

    attr_reader :node_id, :uri

    def remote_node
      @remote_node ||= DRbObject.new_with_uri(uri)
    end

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
          logger.warn "Timeout calling #{method_name} on #{node_id} (attempt #{attempt}/#{retries})"
          attempt += 1
          sleep(0.1) if attempt <= retries
        rescue DRb::DRbConnError, Errno::ECONNREFUSED => e
          logger.warn "Connection error #{method_name} on #{node_id}: #{e.message} (attempt #{attempt}/#{retries})"
          attempt += 1
          sleep(0.1) if attempt <= retries
        rescue StandardError => e
          logger.error "Error calling #{method_name} on #{node_id}: #{e.message}"
          raise
        end
      end

      logger.error "Failed to call #{method_name} on #{node_id} after #{retries} attempts"
      raise DRb::DRbConnError, "Failed to connect to #{node_id} after #{retries} attempts"
    end

    # Request vote from a remote node
    def request_vote(candidate_id, term, last_log_index, last_log_term)
      logger.info "→ Requesting vote from #{node_id} (term #{term})"

      result = call_remote(:request_vote, candidate_id, term, last_log_index, last_log_term)

      vote_response_status = result[:vote_granted] ? 'GRANTED' : 'DENIED'
      logger.info "← Vote response from #{node_id}: #{vote_response_status} (term #{result[:term]})"

      result
    end

    # Send append entries to a remote node
    def append_entries(leader_id, term, prev_log_index, prev_log_term, entries, leader_commit)
      logger.info "→ Sending append_entries to #{node_id} (term #{term}, #{entries.length} entries)"

      result = call_remote(:append_entries, leader_id, term, prev_log_index, prev_log_term, entries, leader_commit)

      append_entries_response_status = result[:success] ? 'SUCCESS' : 'FAILED'
      logger.info "← AppendEntries response from #{node_id}: #{append_entries_response_status} (term #{result[:term]})"

      result
    end

    # Check if a remote node is reachable
    def ping
      logger.info "→ Sending ping to #{node_id}"

      result = call_remote(:ping)

      ping_response_status = result[:success] ? 'SUCCESS' : 'FAILED'
      logger.info "← Ping response from #{node_id}: #{ping_response_status} (term #{result[:term]})"

      result
    end

    private

    attr_reader :port, :timeout, :retries, :logger
  end
end
