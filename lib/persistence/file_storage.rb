require 'json'
require 'fileutils'
require_relative '../config'

# Simple file storage for Raft demo
#
# Provides basic JSON file storage for persisting data
# A production implementation would use a more robust storage solution
# such as a database or a distributed file system.

module Raft
  class FileStorage
    def initialize(file_path)
      @file_path = file_path
      @logger = Config.logger_for(self.class)
      ensure_directory_exists
    end

    def exists?
      File.exist?(file_path)
    end

    def read
      return {} unless exists?

      JSON.parse(File.read(file_path))
    rescue StandardError => e
      logger.error "Error reading file #{file_path}: #{e.message}"
      {}
    end

    def write(data)
      File.write(file_path, JSON.pretty_generate(data))

      logger.debug "Wrote data to #{File.basename(file_path)}"
    rescue StandardError => e
      logger.error "Error writing to file #{file_path}: #{e.message}"
      raise
    end

    private

    attr_reader :file_path, :logger

    def ensure_directory_exists
      FileUtils.mkdir_p(File.dirname(file_path))
    end
  end
end
