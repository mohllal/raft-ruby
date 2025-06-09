require 'json'
require 'fileutils'
require_relative '../config'

# File storage for Raft
#
# This class provides a simple file storage for Raft.
# It allows for reading and writing data to a file.
#
# @param file_path [String] The path to the file to store the data

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
    end

    private

    attr_reader :file_path, :logger

    def ensure_directory_exists
      FileUtils.mkdir_p(File.dirname(file_path))
    end
  end
end
