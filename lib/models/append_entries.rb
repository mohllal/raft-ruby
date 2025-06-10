module Raft
  module Models
    module AppendEntries
      Request = Struct.new(
        :leader_id,
        :term,
        :prev_log_index,
        :prev_log_term,
        :log_entries,
        :leader_commit,
        keyword_init: true
      ) do
        def to_s
          "#{type}(leader: #{leader_id}, term: #{term}, prev: #{prev_log_index}/#{prev_log_term}, " \
            "commit: #{leader_commit})"
        end

        def heartbeat?
          log_entries.nil? || log_entries.empty?
        end

        def type
          heartbeat? ? 'Heartbeat' : "AppendEntries(#{log_entries.length})"
        end
      end

      Response = Struct.new(
        :term,
        :success,
        :last_log_index,
        keyword_init: true
      ) do
        def to_s
          "AppendEntriesResponse(term: #{term}, success: #{success}, last_log: #{last_log_index})"
        end

        def successful?
          success
        end

        def failed?
          !success
        end
      end
    end
  end
end
