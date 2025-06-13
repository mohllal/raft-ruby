#!/usr/bin/env ruby

require_relative '../lib/raft'

# Default cluster configuration
DEFAULT_CLUSTER = {
  'node1' => 8001,
  'node2' => 8002,
  'node3' => 8003
}.freeze

# Create remote node connections
nodes = DEFAULT_CLUSTER.to_h { |id, port| [id, Raft::RemoteNode.new(id, port)] }

puts "\n=== Distributed Raft Cluster Demo ==="
puts "Connecting to: #{DEFAULT_CLUSTER.map { |id, port| "#{id}:#{port}" }.join(', ')}"
puts "=====================================\n\n"

def check_connectivity(nodes) # rubocop:disable Naming/PredicateMethod
  puts '=== Checking Connectivity ==='
  reachable = nodes.count do |id, node|
    node.ping
    puts "#{id}: ✅ Running"
    true
  rescue StandardError
    puts "#{id}: ❌ Not running"
    false
  end
  puts "#{reachable}/#{nodes.size} nodes reachable\n\n"

  if reachable.zero?
    puts 'No nodes running! Start them with: ruby demo/start_node.rb <node_id>'
    false
  else
    true
  end
end

def show_status(nodes)
  puts "\n=== Cluster Status ==="
  nodes.each do |id, node|
    state = node.call_remote(:state)
    term = node.call_remote(:current_term)
    voted = node.call_remote(:voted_for)
    puts "#{id}: #{state} (term #{term}) voted_for: #{voted || 'none'}"
  rescue StandardError
    puts "#{id}: UNREACHABLE"
  end
  puts
end

def trigger_election(nodes, node_id)
  puts "\nTriggering election on #{node_id}..."
  nodes[node_id].call_remote(:start_election)
  puts '✅ Election triggered'
rescue StandardError => e
  puts "❌ Failed: #{e.message}"
end

def watch_cluster(nodes, seconds = 30)
  puts "\n=== Watching cluster for #{seconds} seconds ==="
  (seconds / 5).times do |i|
    puts "\n--- #{i * 5}s ---"
    show_status(nodes)
    sleep(5) unless i == (seconds / 5) - 1
  end
end

# Check initial connectivity
exit unless check_connectivity(nodes)

begin
  loop do
    puts "\n=== MENU ==="
    puts '1. Check connectivity'
    puts '2. Show status'
    puts '3. Trigger election on node1'
    puts '4. Trigger election on node2'
    puts '5. Trigger election on node3'
    puts '6. Watch cluster (30s)'
    puts '7. Exit'
    print "\nChoice: "

    choice = gets&.chomp || '7'

    case choice
    when '1' then check_connectivity(nodes)
    when '2' then show_status(nodes)
    when '3' then trigger_election(nodes, 'node1')
    when '4' then trigger_election(nodes, 'node2')
    when '5' then trigger_election(nodes, 'node3')
    when '6' then watch_cluster(nodes)
    when '7' then break
    else puts 'Invalid choice'
    end
  end
rescue Interrupt
  puts "\nGoodbye!"
end
