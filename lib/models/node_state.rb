# Raft's node state constants
#
# This module defines the three possible states a Raft node can be in:
# - FOLLOWER: A node that is currently following the leader
# - CANDIDATE: A node that is currently running for election to become leader
# - LEADER: A node that is currently the leader

module Raft
  module NodeState
    FOLLOWER = :follower
    CANDIDATE = :candidate
    LEADER = :leader
  end
end
