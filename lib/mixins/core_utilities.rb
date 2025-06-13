# Core utilities mixin
#
# This module provides core utilities for a Raft node.

module Raft
  module CoreUtilities
    # =================== LOG UTILITIES ===================

    # Get last log entry
    def last_log_entry
      log.last
    end

    # Get last log index
    def last_log_index
      log.length
    end

    # Get last log term
    def last_log_term
      last_log_entry&.term || 0
    end

    # Check if candidate's log is at least as up-to-date as ours
    def log_up_to_date?(candidate_last_index, candidate_last_term)
      our_last_term = last_log_term
      our_last_index = last_log_index

      # If terms differ, the one with higher term is more up-to-date
      return candidate_last_term > our_last_term if candidate_last_term != our_last_term

      # If terms are equal, the one with higher index is more up-to-date
      candidate_last_index >= our_last_index
    end

    # =================== STATE UTILITIES ===================

    # Check if node is leader
    def leader?
      state == NodeState::LEADER
    end

    # Check if node is candidate
    def candidate?
      state == NodeState::CANDIDATE
    end

    # Check if node is follower
    def follower?
      state == NodeState::FOLLOWER
    end

    # =================== CLUSTER UTILITIES ===================

    # Get majority count for cluster
    def majority_count
      (cluster_size / 2) + 1
    end

    # Get current cluster size (including self)
    def cluster_size
      remote_nodes.size + 1
    end

    # Check if we have a majority of nodes
    def majority?(count)
      count >= majority_count
    end
  end
end
