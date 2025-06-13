# RPC handlers mixin
#
# This module provides methods for handling RPC requests from other Raft nodes.

module Raft
  module RpcHandlers
    # RequestVote RPC Handler
    def request_vote(request)
      mutex.synchronize do
        logger.info "Received #{request}"

        # Reply false if term < currentTerm
        if request.term < current_term
          logger.info "Rejecting vote for #{request.candidate_id} - term too old (#{request.term} < #{current_term})"
          return Models::RequestVote::Response.new(term: current_term, vote_granted: false)
        end

        # If term > currentTerm, become follower
        become_follower(request.term) if request.term > current_term

        # Grant vote if we haven't voted for anyone else and candidate's log is at least as up-to-date
        can_vote = (voted_for.nil? || voted_for == request.candidate_id) &&
                   log_up_to_date?(request.last_log_index, request.last_log_term)

        if can_vote
          self.voted_for = request.candidate_id
          reset_election_timer

          logger.info "Granted vote to #{request.candidate_id} (term #{request.term})"
          Models::RequestVote::Response.new(term: current_term, vote_granted: true)
        else
          logger.info "Denied vote to #{request.candidate_id} - already voted or log not up to date"
          Models::RequestVote::Response.new(term: current_term, vote_granted: false)
        end
      end
    end

    # AppendEntries RPC Handler
    def append_entries(request)
      mutex.synchronize do
        logger.info "Received #{request}"

        # Reply false if term < currentTerm
        if request.term < current_term
          logger.info "Rejecting AppendEntries from #{request.leader_id} - " \
                      "term too old (#{request.term} < #{current_term})"
          return Models::AppendEntries::Response.new(term: current_term, success: false,
                                                     last_log_index: last_log_index,
                                                     last_log_term: last_log_term)
        end

        # If term >= currentTerm, become follower and reset election timer
        if request.term >= current_term
          become_follower(request.term)
          reset_election_timer
        end

        # Reply false if log doesn't contain an entry at prevLogIndex whose term matches prevLogTerm
        if request.prev_log_index.positive?
          if request.prev_log_index > log.length
            logger.info "Rejecting AppendEntries - missing log entry at index #{request.prev_log_index}"
            return Models::AppendEntries::Response.new(term: current_term, success: false,
                                                       last_log_index: last_log_index,
                                                       last_log_term: last_log_term)
          end

          prev_entry = log[request.prev_log_index - 1]
          if prev_entry.term != request.prev_log_term
            logger.info "Rejecting AppendEntries - log term mismatch at index #{request.prev_log_index}"
            return Models::AppendEntries::Response.new(term: current_term, success: false,
                                                       last_log_index: last_log_index,
                                                       last_log_term: last_log_term)
          end
        end

        # If an existing entry conflicts with a new one, delete the existing entry and all that follow it
        # Append any new entries not already in the log
        unless request.log_entries.empty?
          self.log = log[0...request.prev_log_index] + request.log_entries
          logger.info "Appended #{request.log_entries.length} entries to log"
        end

        # If leaderCommit > commitIndex, set commitIndex = min(leaderCommit, index of last new entry)
        if request.leader_commit > commit_index
          old_commit = commit_index
          self.commit_index = [request.leader_commit, log.length].min

          logger.info "Updated commit index from #{old_commit} to #{commit_index}"
          apply_committed_entries
        end

        Models::AppendEntries::Response.new(term: current_term, success: true, last_log_index: last_log_index)
      end
    end

    # Ping RPC Handler
    def ping
      logger.info 'Received ping'
      Models::Ping::Response.new(success: true, node_id: id, term: current_term)
    end
  end
end
