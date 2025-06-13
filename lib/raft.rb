# Main entry point for the Raft implementation
#
# This file requires all the necessary files for the Raft implementation.

require_relative 'core/raft_node'
require_relative 'rpc/remote_node'

module Raft
  VERSION = '0.1.0'.freeze
end
