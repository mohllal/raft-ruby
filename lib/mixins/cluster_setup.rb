# Cluster setup mixin
#
# This module provides methods for setting up the cluster ports and starting/stopping the DRb server.

module Raft
  module ClusterSetup
    # Set up cluster ports mapping
    def setup_cluster_ports(ports_map)
      ports_map.each do |node_id, port|
        next if node_id == id

        remote_nodes[node_id] = RemoteNode.new(node_id, port)
      end

      logger.info "Cluster ports configured: #{ports_map}"
    end

    # Start DRb server for this node
    def start_drb_server
      return unless port

      self.drb_server = DRbServer.new(self, port)
      drb_server.start

      logger.info "DRb server started for node #{id} on port #{port}"
    end

    # Stop DRb server
    def stop_drb_server
      return unless drb_server

      drb_server.stop
      self.drb_server = nil

      logger.info "DRb server stopped for node #{id}"
    end
  end
end
