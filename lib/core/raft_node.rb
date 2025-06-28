require 'json'
require 'timeout'
require_relative '../models'
require_relative '../config'
require_relative '../persistence'
require_relative '../rpc'
require_relative '../mixins'

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

    attr_reader :id, :state, :current_term, :voted_for, :highest_committed_index

    def initialize(id, port)
      @id = id
      @port = port

      # Persistent state on all servers
      @current_term = 0
      @voted_for = nil
      @log = [] # Array of LogEntry objects

      @highest_committed_index = 0 # The highest index that has been committed
      @applied_up_to_index = 0 # The highest index that has been applied to the state machine

      # Volatile state on leaders (reinitialized after election)
      @next_index = {} # Leader: next log index to send to each follower
      @match_index = {} # Leader: highest log index known to be replicated

      # Node state
      @state = NodeState::FOLLOWER

      # State machine
      @state_machine = StateMachine.new(id)

      # Cluster remote nodes and DRb server
      @remote_nodes = {}
      @drb_server = nil

      # Election timing
      @election_timer = nil
      @heartbeat_timer = nil

      # Thread safety
      @mutex = Mutex.new

      # Logging
      @logger = Config.logger_for(self.class)

      # Initialize log storage and load persistent state
      initialize_log_storage

      # Start election timer (all nodes start as followers)
      start_election_timer

      logger.info "Node #{id} initialized as #{state}"
    end

    private

    attr_accessor :drb_server, :election_timer, :heartbeat_timer, :log, :applied_up_to_index
    attr_reader :logger, :mutex, :state_machine, :remote_nodes, :port, :next_index, :match_index
    attr_writer :state, :current_term, :voted_for, :highest_committed_index
  end
end
