module Raft
  module Models
    module RequestVote
      Request = Struct.new(
        :candidate_id,
        :term,
        :last_log_index,
        :last_log_term,
        keyword_init: true
      ) do
        def to_s
          "RequestVote(candidate: #{candidate_id}, term: #{term}, last_log: #{last_log_index}/#{last_log_term})"
        end
      end

      Response = Struct.new(
        :term,
        :vote_granted,
        keyword_init: true
      ) do
        def to_s
          "RequestVoteResponse(term: #{term}, granted: #{vote_granted})"
        end

        def granted?
          vote_granted
        end
      end
    end
  end
end
