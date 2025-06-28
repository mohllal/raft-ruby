#!/usr/bin/env ruby

# Distributed Raft Cluster Demo Client
#
# This script connects to a running Raft cluster. It does NOT start the cluster nodes - those
# must be started separately.
#
# Usage:
# 1. First, start the cluster nodes in separate terminals:
#    - Terminal 1: ruby demo/start_node.rb node1
#    - Terminal 2: ruby demo/start_node.rb node2
#    - Terminal 3: ruby demo/start_node.rb node3
# 2. Once nodes are running, start this demo client:
#    ruby demo/distributed_cluster_demo.rb
# 3. Use interactive commands: status, add <key> <value>, quit

require 'drb/drb'
require 'timeout'
require_relative '../lib/raft'

# Default cluster configuration
DEFAULT_CLUSTER = {
  'node1' => 8001,
  'node2' => 8002,
  'node3' => 8003
}.freeze

# Global variables for the demo
nodes = {}

# Helper functions
def connect_to_nodes(nodes, ports)
  ports.each do |node_id, port|
    node = DRbObject.new_with_uri("druby://localhost:#{port}")
    # Test connection
    node.ping
    nodes[node_id] = node
    puts "✓ Connected to #{node_id} on port #{port}"
  rescue StandardError => e
    puts "✗ Failed to connect to #{node_id} on port #{port}: #{e.message}"
  end
end

def show_cluster_state(nodes)
  puts "\n=== Current Cluster State ==="
  nodes.each do |node_id, node|
    state = node.state
    term = node.current_term
    last_log_index = node.last_log_index
    puts "#{node_id}: #{state} (term: #{term}, log index: #{last_log_index})"
  rescue StandardError => e
    puts "#{node_id}: ERROR - #{e.message}"
  end
end

def wait_for_leader(nodes, timeout = 30)
  start_time = Time.now

  while Time.now - start_time < timeout
    nodes.each do |node_id, node|
      return node_id if node.state == :leader
    rescue StandardError => e
      puts "Error getting state for #{node_id}: #{e.message}"
    end
    sleep(0.5)
  end

  nil
end

def find_leader(nodes)
  nodes.each do |node_id, node|
    return node_id if node.state == :leader
  rescue StandardError => e
    puts "Error finding leader: #{e.message}"
  end
  nil
end

def add_log_entry(nodes, key, value)
  leader_id = find_leader(nodes)
  unless leader_id
    puts 'No leader found!'
    return
  end

  leader = nodes[leader_id]
  command = { type: 'SET', key: key, value: value }

  begin
    entry = leader.add_log_entry(command)
    puts "✓ Added log entry through #{leader_id}: #{entry}"
  rescue StandardError => e
    puts "✗ Failed to add log entry: #{e.message}"
  end
end

# Set up signal handler for clean exit
Signal.trap('INT') do
  puts "\n\nInterrupted! Exiting demo..."
  exit 0
end

# Main script
puts '=== Distributed Raft Cluster Demo ==='
puts
puts 'This demo shows a 3-node Raft cluster with real network communication.'
puts
puts 'To start the cluster, run these commands in separate terminals:'
puts '  ruby demo/start_node.rb node1'
puts '  ruby demo/start_node.rb node2'
puts '  ruby demo/start_node.rb node3'
puts
puts 'Press Enter once all nodes are started (or Ctrl+C to exit)...'

begin
  gets
rescue Interrupt
  puts "\n\nInterrupted! Exiting demo..."
  exit 0
end

# Try to connect to all nodes
connect_to_nodes(nodes, DEFAULT_CLUSTER)

if nodes.empty?
  puts 'ERROR: No nodes found! Make sure the nodes are running.'
  exit 1
end

# Show initial cluster state
show_cluster_state(nodes)

# Wait for leader election
puts "\nWaiting for leader election..."
leader = wait_for_leader(nodes)

if leader
  puts "\n✓ Leader elected: #{leader}"
else
  puts "\n✗ No leader elected after timeout"
  exit 1
end

# Demonstrate cluster behavior
puts "\n=== Demonstrating Cluster Behavior ==="

# Show heartbeats
puts "\n1. Heartbeats:"
puts '   The leader is sending heartbeats to maintain leadership.'
puts '   Watch the node logs to see AppendEntries messages.'
sleep(2)

# Add a log entry
puts "\n2. Log Replication:"
leader_id = find_leader(nodes)
if leader_id
  leader_node = nodes[leader_id]
  command = { type: 'SET', key: 'demo_key', value: 'demo_value' }

  puts "   Adding log entry through leader (#{leader_id})..."
  begin
    entry = leader_node.add_log_entry(command)
    puts "   ✓ Log entry added: #{entry}"

    # Wait for replication
    sleep(1)

    # Check replication
    puts "\n   Checking replication status:"
    nodes.each do |node_id, node|
      log_length = node.last_log_index
      commit_index = node.commit_index
      puts "   #{node_id}: log length = #{log_length}, commit index = #{commit_index}"
    rescue StandardError => e
      puts "   #{node_id}: ERROR - #{e.message}"
    end
  rescue StandardError => e
    puts "   ✗ Failed to add log entry: #{e.message}"
  end
end

# Simulate failure
puts "\n3. Fault Tolerance:"
puts '   You can test fault tolerance by:'
puts '   - Stopping the leader (Ctrl+C) and watching a new election'
puts '   - Stopping a follower and seeing the cluster continue'
puts '   - Restarting a stopped node and watching it catch up'

# Interactive mode
puts "\n4. Interactive Mode:"
puts '   Commands:'
puts '   - status: Show cluster status'
puts '   - add <key> <value>: Add a log entry'
puts '   - quit: Exit demo'

# Interactive loop
begin
  loop do
    print "\n> "
    input = gets

    # Handle nil input (Ctrl+D or EOF)
    if input.nil?
      puts "\nExiting demo..."
      break
    end

    input = input.chomp.split

    case input[0]
    when 'status'
      show_cluster_state(nodes)
    when 'add'
      if input.length < 3
        puts 'Usage: add <key> <value>'
      else
        add_log_entry(nodes, input[1], input[2])
      end
    when 'quit', 'exit'
      puts 'Exiting demo...'
      break
    when nil
      puts 'Invalid input, use status, add, or quit'
    else
      puts "Unknown command: #{input[0]}"
    end
  end
rescue Interrupt
  puts "\n\nInterrupted! Exiting demo..."
  exit 0
end
