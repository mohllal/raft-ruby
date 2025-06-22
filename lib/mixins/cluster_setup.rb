# Cluster setup mixin
#
# This module provides methods for setting up the cluster of Raft nodes.

module Raft
  module ClusterSetup
    def configure_cluster(node_ids_and_ports)
      # Initialize cluster with predefined nodes and their ports
      # node_ids_and_ports is a hash like { 'node1' => 8001, 'node2' => 8002, 'node3' => 8003 }

      # Create remote node connections
      node_ids_and_ports.each do |node_id, node_port|
        next if node_id == id # Skip self

        remote_nodes[node_id] = RemoteNode.new(node_id, node_port)
        logger.info "Configured remote node: #{node_id} at port #{node_port}"
      end

      logger.info "Cluster configured with #{remote_nodes.size} remote nodes"
    end

    def start_rpc_server
      # Start DRb server for this node
      DRb.start_service("druby://localhost:#{port}", self)
      self.drb_server = DRb.thread

      logger.info "DRb server started on port #{port}"
    end

    def stop_rpc_server
      DRb.stop_service if DRb.primary_server
      logger.info 'DRb server stopped'
    end

    def cluster_ready?
      # Check if all remote nodes are reachable
      reachable_count = 0

      remote_nodes.each do |node_id, remote_node|
        if remote_node.ping
          reachable_count += 1
          logger.debug "Node #{node_id} is reachable"
        else
          logger.warn "Node #{node_id} is not reachable"
        end
      end

      logger.info "Cluster status: #{reachable_count}/#{remote_nodes.size} remote nodes reachable"
      reachable_count == remote_nodes.size
    end
  end
end
