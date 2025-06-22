require 'logger'
require 'dotenv/load'

# Raft configuration
module Raft
  module Config
    # Timing settings (in seconds)
    ELECTION_TIMEOUT_MIN = ENV.fetch('RAFT_ELECTION_TIMEOUT_MIN', 5.0).to_f
    ELECTION_TIMEOUT_MAX = ENV.fetch('RAFT_ELECTION_TIMEOUT_MAX', 10.0).to_f
    HEARTBEAT_INTERVAL = ENV.fetch('RAFT_HEARTBEAT_INTERVAL', 1.0).to_f
    RPC_TIMEOUT = ENV.fetch('RAFT_RPC_TIMEOUT', 2.0).to_f
    RPC_RETRIES = ENV.fetch('RAFT_RPC_RETRIES', 3).to_i

    # Storage directories
    DATA_DIR = ENV.fetch('RAFT_DATA_DIR', 'data')
    LOG_DIR = ENV.fetch('RAFT_LOG_DIR', 'logs')

    # Storage files
    STATE_FILE = ENV.fetch('RAFT_STATE_FILE', 'state.json')
    LOG_FILE = ENV.fetch('RAFT_LOG_FILE', 'log.json')
    METADATA_FILE = ENV.fetch('RAFT_METADATA_FILE', 'metadata.json')

    # Logging
    LOG_LEVEL = ENV.fetch('RAFT_LOG_LEVEL', 'INFO')

    def self.logger_for(klass)
      logger = Logger.new($stdout)
      logger.level = Logger.const_get(LOG_LEVEL.upcase)
      logger.progname = klass.name.split('::').last
      logger.formatter = proc do |severity, datetime, progname, msg|
        "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity} #{progname}: #{msg}\n"
      end
      logger
    end
  end
end
