# Raft's simple log entry structure
#
# This class represents a log entry in the Raft algorithm.
# It contains the term, index, and command for the entry.
#
# @param term [Integer] The term of the log entry
# @param index [Integer] The index of the log entry
# @param command [Object] The command for the log entry

module Raft
  class LogEntry
    def initialize(term, index, command)
      @term = term
      @index = index
      @command = command
    end

    attr_reader :term, :index, :command

    def to_s
      "LogEntry(term=#{term}, index=#{index}, command=#{command})"
    end
  end
end
