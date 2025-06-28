# Log management mixin
#
# This module provides methods for managing the log and metadata of a Raft node.
#
# The log is used to store the log entries for a Raft node.
# The metadata is used to store the current term, voted for, commit index, and last applied log index.

module Raft
  module LogManagement
    # Initialize log storage
    def initialize_log_storage
      @log_persistence = LogPersistence.new(id)
      load_persistent_state
    end

    # Load log and metadata from disk
    def load_persistent_state
      # Load log entries
      self.log = log_persistence.load_log

      # Load metadata (returns Metadata instance)
      metadata = log_persistence.load_metadata
      self.current_term = metadata.current_term
      self.voted_for = metadata.voted_for
      self.commit_index = metadata.commit_index
      self.last_applied = metadata.last_applied

      logger.info "Loaded persistent state: term=#{current_term}, log_size=#{log.length}, " \
                  "commit=#{commit_index}, applied=#{last_applied}"
    end

    # Persist current state to disk
    def persist_state
      persist_log
      persist_metadata
    end

    # Persist metadata
    def persist_metadata
      metadata = Models::Metadata.new(
        current_term: current_term,
        voted_for: voted_for,
        commit_index: commit_index,
        last_applied: last_applied
      )
      log_persistence.save_metadata(metadata)
    end

    # Persist log entries
    def persist_log
      log_persistence.save_log(log)
    end

    # Add a new log entry (for leaders)
    def add_log_entry(command)
      return if state != NodeState::LEADER

      entry = Models::LogEntry.new(term: current_term, index: last_log_index + 1, command: command)
      log << entry

      persist_state
      logger.info "Appended log entry: #{entry}"

      # Start replicating to followers
      replicate_log_entries

      entry
    end

    # Apply committed entries to state machine
    def apply_committed_entries
      while last_applied < commit_index
        self.last_applied += 1
        next unless self.last_applied <= log.length

        entry = log[last_applied - 1]
        result = state_machine.apply(entry.command)
        logger.info "Applied entry #{last_applied}: #{entry.command} => #{result}"
      end

      # Persist updated last_applied
      persist_metadata
    end

    # Replicate log entries to followers (for leaders)
    def replicate_log_entries
      return unless state == NodeState::LEADER

      remote_nodes.each do |node_id, node|
        Thread.new { replicate_to_follower(node_id, node) }
      end
    end

    # Replicate entries to a specific follower
    def replicate_to_follower(follower_id, follower_node)
      next_idx = next_index[follower_id] || 1

      # Get last log index and term
      prev_log_index = next_idx - 1
      prev_log_term = 0
      prev_log_term = log[prev_log_index - 1].term if prev_log_index.positive? && prev_log_index <= log.length

      # Send entries from next_idx onwards (one at a time for simplicity)
      entries_to_send = []
      entries_to_send = [log[next_idx - 1]] if next_idx <= log.length

      request = Models::AppendEntries::Request.new(
        leader_id: id,
        term: current_term,
        prev_log_index: prev_log_index,
        prev_log_term: prev_log_term,
        log_entries: entries_to_send,
        leader_commit: commit_index
      )

      logger.debug "Sending #{request.type} to #{follower_id} (next_idx: #{next_idx})"

      begin
        response = Timeout.timeout(Config::RPC_TIMEOUT) do
          follower_node.append_entries(request)
        end

        handle_append_entries_response(follower_id, request, response)
      rescue StandardError => e
        logger.error "Failed to replicate to #{follower_id}: #{e.message}"
      end
    end

    # Handle response from append_entries RPC
    def handle_append_entries_response(follower_id, request, response)
      mutex.synchronize do
        # If response contains higher term, step down
        if response.term > current_term
          logger.info "Received higher term #{response.term} from #{follower_id}, stepping down"
          become_follower(response.term)
          return
        end

        if response.successful?
          # Update nextIndex and matchIndex for follower
          sent_entries = request.log_entries || []
          if sent_entries.any?
            match_index[follower_id] = request.prev_log_index + sent_entries.length
            next_index[follower_id] = match_index[follower_id] + 1
            logger.debug "Updated indices for #{follower_id}: next=#{next_index[follower_id]}, " \
                         "match=#{match_index[follower_id]}"
          end

          # Check if we can advance commit index
          advance_commit_index

          # Continue replicating if there are more entries
          if next_index[follower_id] <= log.length
            Thread.new { replicate_to_follower(follower_id, remote_nodes[follower_id]) }
          end
        else
          # Decrement nextIndex and retry
          next_index[follower_id] = [1, (next_index[follower_id] || 1) - 1].max
          logger.debug "AppendEntries failed for #{follower_id}, decremented nextIndex to #{next_index[follower_id]}"

          # Retry with updated index
          Thread.new { replicate_to_follower(follower_id, remote_nodes[follower_id]) }
        end
      end
    end

    # Advance commit index based on match indices
    def advance_commit_index
      return unless state == NodeState::LEADER

      # Find the highest index that a majority of nodes have
      match_indices = match_index.values + [log.length]
      sorted_indices = match_indices.sort.reverse

      majority_size = (match_indices.length / 2) + 1
      new_commit_index = sorted_indices[majority_size - 1]

      # Only advance if the entry is from current term
      if new_commit_index > commit_index &&
         new_commit_index <= log.length &&
         log[new_commit_index - 1].term == current_term

        old_commit = commit_index
        self.commit_index = new_commit_index
        logger.info "Advanced commit index from #{old_commit} to #{commit_index}"

        # Apply newly committed entries
        apply_committed_entries

        # Persist the new commit index
        persist_metadata
      end
    end

    # Handle log conflicts during append_entries
    def handle_log_conflicts(prev_log_index, prev_log_term, new_entries) # rubocop:disable Naming/PredicateMethod
      # Check if we have the previous entry
      if prev_log_index.positive?
        if prev_log_index > log.length
          # We're missing entries
          logger.debug "Missing entries: our log ends at #{log.length}, but prev_log_index is #{prev_log_index}"
          return false
        end

        # Check if previous entry matches
        prev_entry = log[prev_log_index - 1]
        if prev_entry.term != prev_log_term
          # Conflict detected - remove this and all following entries
          logger.info "Log conflict at index #{prev_log_index}: expected term #{prev_log_term}, got #{prev_entry.term}"
          self.log = log[0...prev_log_index - 1]
          persist_state
        end
      end

      # Append new entries
      if new_entries && !new_entries.empty?
        # Remove any conflicting entries
        insert_index = prev_log_index
        new_entries.each_with_index do |new_entry, idx|
          current_index = insert_index + idx
          if current_index < log.length && log[current_index].term != new_entry.term
            # Conflict - truncate log
            self.log = log[0...current_index]
          end
        end

        # Append new entries
        self.log = log[0...insert_index] + new_entries
        persist_state
        logger.info "Appended #{new_entries.length} entries to log"
      end

      true
    end

    private

    attr_reader :log_persistence
  end
end
