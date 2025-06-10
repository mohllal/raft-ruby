module Raft
  module Models
    LogEntry = Struct.new(
      :term,
      :index,
      :command,
      keyword_init: true
    ) do
      def to_s
        "LogEntry(term=#{term}, index=#{index}, command=#{command})"
      end
    end
  end
end
