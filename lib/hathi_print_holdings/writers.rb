module HathiPrintHoldings
  module Writing

    def self.set_files(exclude:, warn:)
      @exclude_file = exclude
      @warn_file = warn
    end

    def self.exclude_file
      @exclude_file
    end

    def self.warn_file
      @warn_file || STDOUT
    end

    def write_exclude(message_array)
      return unless HathiPrintHoldings::Writing.exclude_file
      HathiPrintHoldings::Writing.exclude_file << message_array
    end

    def write_warn(message_array)
      HathiPrintHoldings::Writing.warn_file << message_array
    end
  end
end
