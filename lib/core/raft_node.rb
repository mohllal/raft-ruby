require 'json'
require 'timeout'
require_relative 'node_state'
require_relative '../models'
require_relative '../config'
require_relative '../persistence/state_machine'
require_relative '../rpc/drb_server'
require_relative '../rpc/remote_node'
require_relative '../mixins/core_utilities'
require_relative '../mixins/state_transitions'
require_relative '../mixins/cluster_setup'
require_relative '../mixins/log_management'
require_relative '../mixins/election_management'
require_relative '../mixins/heartbeat_management'
require_relative '../mixins/rpc_handlers'

# Main Raft Node implementation
module Raft
  class RaftNode
    include CoreUtilities
    include StateTransitions
    include ClusterSetup
    include LogManagement
    include ElectionManagement
    include HeartbeatManagement
    include RpcHandlers

    attr_reader :id, :state, :current_term, :voted_for

    def initialize(id, cluster_nodes = [], port = nil)
      @id = id
      @cluster_nodes = cluster_nodes
      @port = port

      # Persistent state on all servers
      @current_term = 0
      @voted_for = nil
      @log = [] # Array of LogEntry objects

      # Volatile state on all servers
      @commit_index = 0
      @last_applied = 0

      # Volatile state on leaders (reinitialized after election)
      @next_index = {}    # For each server, index of next log entry to send
      @match_index = {}   # For each server, index of highest log entry known to be replicated

      # Node state
      @state = NodeState::FOLLOWER

      # State machine
      @state_machine = StateMachine.new(id)

      # Distributed communication
      @remote_nodes = {}
      @drb_server = nil

      # Election timing
      @election_timer = nil
      @heartbeat_timer = nil

      # Thread safety
      @mutex = Mutex.new

      # Logging
      @logger = Config.logger_for(self.class)

      logger.info "Node #{id} initialized as #{state}"
    end

    private

    attr_accessor :drb_server, :election_timer, :heartbeat_timer, :log, :commit_index, :last_applied
    attr_reader :logger, :mutex, :state_machine, :remote_nodes, :port, :next_index, :match_index, :cluster_nodes
    attr_writer :state, :current_term, :voted_for
  end
end
