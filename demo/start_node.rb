#!/usr/bin/env ruby

require_relative '../lib/raft'

# Default cluster configuration
DEFAULT_CLUSTER = {
  'node1' => 8001,
  'node2' => 8002,
  'node3' => 8003
}.freeze

node_id = ARGV[0]

unless node_id && DEFAULT_CLUSTER.key?(node_id)
  puts "Usage: #{$PROGRAM_NAME} <node_id>"
  puts "Available nodes: #{DEFAULT_CLUSTER.keys.join(', ')}"
  exit 1
end

port = DEFAULT_CLUSTER[node_id]

puts '=== Starting Raft Node ==='
puts "Node ID: #{node_id}"
puts "Port: #{port}"
puts "Cluster: #{DEFAULT_CLUSTER.map { |id, p| "#{id}:#{p}" }.join(', ')}"
puts '========================='
puts

# Create and configure the node
node = Raft::RaftNode.new(node_id, port)
node.configure_cluster(DEFAULT_CLUSTER)
node.start_rpc_server

puts "Node #{node_id} is running on port #{port}"
puts "DRb URI: druby://localhost:#{port}"
puts
puts 'The node will:'
puts '1. Start as a follower'
puts '2. Begin election timeout (150-300ms)'
puts '3. Participate in leader election'
puts '4. Send/receive heartbeats'
puts '5. Replicate log entries'
puts
puts 'Press Ctrl+C to stop the node'
puts

# Keep the node running
begin
  DRb.thread.join
rescue Interrupt
  puts "\nShutting down node #{node_id}..."
  node.stop_rpc_server
  exit 0
end
