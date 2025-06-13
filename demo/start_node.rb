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
  puts "Error: Please specify a valid node ID (#{DEFAULT_CLUSTER.keys.join(', ')})"
  puts 'Usage: ruby demo/start_node.rb <node_id>'
  exit 1
end

port = DEFAULT_CLUSTER[node_id]

puts '=== Starting Raft Node ==='
puts "Node ID: #{node_id}"
puts "Port: #{port}"
puts '=========================='

begin
  # Create and configure Raft node
  node = Raft::RaftNode.new(node_id, port)
  node.setup_cluster_ports(DEFAULT_CLUSTER)
  node.start_drb_server

  puts "Node #{node_id} started successfully!"
  puts "DRb URI: druby://localhost:#{port}"
  puts 'Press Ctrl+C to stop...'
  puts

  # Keep the node running
  loop do
    sleep(1)

    # Display status every 10 seconds
    if (Time.now.to_i % 10).zero?
      puts "#{Time.now.strftime('%H:%M:%S')} - Node #{node_id}: #{node.state} (term #{node.current_term})"
    end
  end
rescue Interrupt
  puts "\nShutting down node #{node_id}..."
rescue StandardError => e
  puts "Error starting node: #{e.message}"
  puts e.backtrace
  exit 1
ensure
  if node
    node.stop_drb_server
    puts "Node #{node_id} stopped."
  end
end
