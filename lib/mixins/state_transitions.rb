require_relative '../core/node_state'

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

      # Stop election timer
      stop_election_timer

      logger.info "Became candidate (term #{current_term})"
    end

    # Transition to leader state
    def become_leader
      self.state = NodeState::LEADER

      # Reset cluster nodes state to leader state
      cluster_nodes.each do |node_id|
        next if node_id == id

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
