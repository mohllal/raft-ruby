require 'drb'
require_relative '../config'

# DRb server wrapper for Raft nodes
#
# This class provides a wrapper for the DRb server that is used to communicate with remote nodes.
# It allows for starting and stopping the DRb server, and for exposing a node for remote access.

module Raft
  class DRbServer
    def initialize(node, port)
      @node = node
      @port = port
      @logger = Config.logger_for(self.class)
      @server_thread = nil
    end

    # Start the DRb server
    def start
      return if server_thread&.alive?

      begin
        uri = "druby://localhost:#{port}"

        DRb.start_service(uri, node)

        logger.info "DRb server started on #{uri}"
        logger.info "Exposing node #{node.id} for remote access"

        # Keep server running in background thread
        self.server_thread = Thread.new do
          Thread.current.abort_on_exception = true
          DRb.thread.join
        end

        server_thread
      rescue StandardError => e
        logger.error "Failed to start DRb server: #{e.message}"
        raise
      end
    end

    # Stop the DRb server
    def stop
      return unless server_thread&.alive?

      logger.info "Stopping DRb server on port #{port}"
      DRb.stop_service
      server_thread.kill if server_thread.alive?
      self.server_thread = nil
    end

    private

    attr_reader :node, :port, :logger
    attr_accessor :server_thread
  end
end
