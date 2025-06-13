# Heartbeat management mixin
#
# This module provides methods for managing the heartbeat of a leader node.

module Raft
  module HeartbeatManagement
    # Send heartbeats to all followers (leader only)
    def send_heartbeats
      return unless leader?

      logger.debug 'Sending heartbeats to followers'

      remote_nodes.each do |node_id, remote_node|
        Thread.new do
          prev_log_index = next_index[node_id] - 1
          prev_log_term = prev_log_index.positive? ? log[prev_log_index - 1].term : 0

          append_request = Models::AppendEntries::Request.new(
            leader_id: id,
            term: current_term,
            prev_log_index: prev_log_index,
            prev_log_term: prev_log_term,
            log_entries: [],
            leader_commit: commit_index
          )
          response = remote_node.append_entries(append_request)

          mutex.synchronize do
            if response.term > current_term
              logger.info "Discovered higher term #{response.term} from #{node_id} - stepping down"
              become_follower(response.term)
            end
          end
        rescue StandardError => e
          logger.debug "Failed to send heartbeat to #{node_id}: #{e.message}"
        end
      end
    end

    # Reset heartbeat timer
    def reset_heartbeat_timer
      stop_heartbeat_timer
      start_heartbeat_timer
    end

    # Start heartbeat timer (leader only)
    def start_heartbeat_timer
      self.heartbeat_timer = Thread.new do
        while leader?
          send_heartbeats
          sleep(Config::HEARTBEAT_INTERVAL)
        end
      end
    end

    # Stop heartbeat timer
    def stop_heartbeat_timer
      return unless heartbeat_timer

      heartbeat_timer.kill
      self.heartbeat_timer = nil
    end
  end
end
