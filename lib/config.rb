require 'logger'
require 'dotenv/load'

module Raft
  module Config
    # Logging Configuration
    LOG_LEVEL = ENV.fetch('LOG_LEVEL', 'INFO')

    # Raft Configuration
    HEARTBEAT_INTERVAL = ENV.fetch('RAFT_HEARTBEAT_INTERVAL', '1.0').to_f
    ELECTION_TIMEOUT_MIN = ENV.fetch('RAFT_ELECTION_TIMEOUT_MIN', '5.0').to_f
    ELECTION_TIMEOUT_MAX = ENV.fetch('RAFT_ELECTION_TIMEOUT_MAX', '10.0').to_f
    REQUEST_TIMEOUT = ENV.fetch('RAFT_REQUEST_TIMEOUT', '2.0').to_f

    # Node Configuration
    NODE_ID = ENV.fetch('NODE_ID', 'node1')
    NODE_PORT = ENV.fetch('NODE_PORT', '8001').to_i
    CLUSTER_NODES = ENV.fetch('CLUSTER_NODES', 'localhost:8001,localhost:8002,localhost:8003').split(',').map(&:strip)

    # Storage Configuration
    DATA_DIR = ENV.fetch('DATA_DIR', './logs')
    STATE_MACHINE_FILE = ENV.fetch('STATE_MACHINE_FILE', 'state_machine.json')
    PERSISTENCE_ENABLED = ENV.fetch('PERSISTENCE_ENABLED', 'true').downcase == 'true'

    # Simple logger method that creates loggers for specific classes
    def self.logger_for(klass)
      logger = Logger.new($stdout)
      logger.level = Logger.const_get(LOG_LEVEL.upcase)
      logger.progname = klass.name
      logger.formatter = proc do |severity, datetime, progname, msg|
        "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity} #{progname}: #{msg}\n"
      end
      logger
    end
  end
end
