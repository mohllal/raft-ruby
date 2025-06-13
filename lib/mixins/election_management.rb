require_relative '../config'

module Raft
  module ElectionManagement
    # Start election process
    def start_election
      become_candidate
      logger.info "Starting election for term #{current_term}"

      votes_received = 1 # Vote for self
      votes_needed = majority_count
      logger.info "Need #{votes_needed} votes, got 1 (self)"

      # Request votes from all other nodes
      logger.info "Requesting votes from #{remote_nodes.keys.join(', ')}"

      remote_nodes.each do |node_id, remote_node|
        Thread.new do
          logger.debug "Sending vote request to #{node_id}"
          vote_request = Models::RequestVote::Request.new(
            candidate_id: id,
            term: current_term,
            last_log_index: last_log_index,
            last_log_term: last_log_term
          )
          response = remote_node.request_vote(vote_request)
          logger.debug "Received vote response from #{node_id}: #{response}"

          # Process the vote response
          mutex.synchronize do
            # Only process if we're still a candidate in the same term
            if state == NodeState::CANDIDATE && current_term == response.term
              if response.granted?
                votes_received += 1
                logger.info "Received vote from #{node_id} (#{votes_received}/#{votes_needed})"

                # Check if we won the election
                if votes_received >= votes_needed
                  logger.info "Won election with #{votes_received} votes!"
                  become_leader
                  send_heartbeats
                end
              end
            elsif response.term > current_term
              # Discovered higher term, become follower
              logger.info "Discovered higher term #{response.term} from #{node_id}"
              become_follower(response.term)
            end
          end
        rescue StandardError => e
          logger.warn "Failed to get vote from #{node_id}: #{e.message}"
        end
      end
    end

    # Reset election timer
    def reset_election_timer
      stop_election_timer
      start_election_timer
    end

    # Start election timer (follower and candidate only)
    def start_election_timer
      timeout_range = Config::ELECTION_TIMEOUT_MIN..Config::ELECTION_TIMEOUT_MAX
      election_timeout = rand(timeout_range)

      self.election_timer = Thread.new do
        sleep(election_timeout)

        if state != NodeState::LEADER
          logger.info 'Election timeout - starting election'
          start_election
        end
      end
    end

    # Stop election timer
    def stop_election_timer
      return unless election_timer

      election_timer.kill if election_timer != Thread.current
      self.election_timer = nil
    end
  end
end
