module Raft
  module Models
    module Ping
      Response = Struct.new(
        :success,
        :node_id,
        :term,
        keyword_init: true
      ) do
        def to_s
          "PingResponse(node: #{node_id}, term: #{term}, success: #{success})"
        end

        def successful?
          success
        end
      end
    end
  end
end
