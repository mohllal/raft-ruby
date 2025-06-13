# State transitions mixin
#
# This module provides methods for transitioning between different states of a Raft node.

module Raft
  module StateTransitions
    # Transition to follower state
    def become_follower(term)
      old_state = state

      self.current_term = term if term > current_term
      self.state = NodeState::FOLLOWER
      self.voted_for = nil

      # Stop heartbeat timer if we were leader
      stop_heartbeat_timer if old_state == NodeState::LEADER

      # Reset election timer
      reset_election_timer

      logger.info "Became follower (term #{current_term})"
    end

    # Transition to candidate state
    def become_candidate
      self.state = NodeState::CANDIDATE
      self.current_term += 1
      self.voted_for = id

      # Reset election timer to retry if this election fails (no majority votes)
      reset_election_timer

      logger.info "Became candidate (term #{current_term})"
    end

    # Transition to leader state
    def become_leader
      self.state = NodeState::LEADER

      # Initialize next_index and match_index for all remote nodes
      remote_nodes.each_key do |node_id|
        next_index[node_id] = last_log_index + 1
        match_index[node_id] = 0
      end

      # Stop election timer since we go to leader state
      stop_election_timer

      # Reset heartbeat timer
      reset_heartbeat_timer

      logger.info "Became leader (term #{current_term})"
    end
  end
end
