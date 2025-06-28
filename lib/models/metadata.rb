module Raft
  module Models
    Metadata = Struct.new(
      :current_term,
      :voted_for,
      :commit_index,
      :last_applied,
      :updated_at,
      keyword_init: true
    ) do
      # Create a Metadata instance from a hash
      def self.from_hash(hash)
        return nil unless hash

        # Return default metadata for empty hash
        if hash.empty?
          return new(
            current_term: 0,
            voted_for: nil,
            commit_index: 0,
            last_applied: 0,
            updated_at: Time.now.to_s
          )
        end

        new(
          current_term: hash['current_term'] || hash[:current_term] || 0,
          voted_for: hash['voted_for'] || hash[:voted_for] || nil,
          commit_index: hash['commit_index'] || hash[:commit_index] || 0,
          last_applied: hash['last_applied'] || hash[:last_applied] || 0,
          updated_at: hash['updated_at'] || hash[:updated_at] || Time.now.to_s
        )
      end

      def update_timestamp
        self.updated_at = Time.now.to_s
        self
      end

      def to_s
        "Metadata(term=#{current_term}, voted_for=#{voted_for}, " \
          "commit=#{commit_index}, applied=#{last_applied})"
      end
    end
  end
end
