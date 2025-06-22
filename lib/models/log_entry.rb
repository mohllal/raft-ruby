module Raft
  module Models
    # Log entry for Raft
    LogEntry = Struct.new(
      :term,
      :index,
      :command,
      keyword_init: true
    ) do
      # Create a LogEntry instance from a hash
      def self.from_hash(hash)
        return nil unless hash

        new(
          term: hash['term'] || hash[:term],
          index: hash['index'] || hash[:index],
          command: hash['command'] || hash[:command]
        )
      end

      def to_s
        "LogEntry(term=#{term}, index=#{index}, cmd=#{command_summary})"
      end

      private

      def command_summary
        return 'nil' unless command

        if command.is_a?(Hash)
          type = command['type'] || command[:type]
          key = command['key'] || command[:key]
          "#{type} #{key}"
        else
          command.to_s
        end
      end
    end
  end
end
