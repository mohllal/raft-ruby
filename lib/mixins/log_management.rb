module Raft
  module LogManagement
    # Add a new log entry (for leaders)
    def add_log_entry(command)
      entry = Models::LogEntry.new(term: current_term, index: last_log_index + 1, command: command)
      log << entry
      logger.info "Added log entry: #{entry}"
      entry
    end

    # Apply committed entries to state machine
    def apply_committed_entries
      while last_applied < commit_index
        self.last_applied += 1
        next unless self.last_applied <= log.length

        entry = log[last_applied - 1] # Array is 0-indexed
        result = state_machine.apply(entry.command)
        logger.info "Applied entry #{last_applied}: #{entry.command} => #{result}"
      end
    end
  end
end
