require_relative '../../../sierra-postgres-utilities/lib/sierra_postgres_utilities.rb'

module HathiPrintHoldings
  module Compare

    def compare_to(hsh)
      @sierra = hsh
    end

    def added
      @sierra.reject { |k,v| self.include?(k) }
    end

    def added_flat
      self.added.each do |k,v|
        puts "#{k}:"
        puts "val: y"
        puts "desc: #{@sierra[k]}"
      end
      nil
    end

    def removed
      self.reject { |k,v| @sierra.include?(k) }
    end

    def changed
      self.select { |k,v| @sierra[k] && @sierra[k] != v['desc'] }.
            each { |k,v| v['sierra_desc'] = @sierra[k] }
    end

    def changed_flat
      self.changed.each do |k,v|
        puts k
        puts "hathi: #{v['desc']}"
        puts "sierra: #{v['sierra_desc']}"
      end
      nil
    end

    def included
      self.select { |k,v| v['val'] == 'y' }
    end

    def excluded
      self.select { |k,v| v['val'] == 'n' }
    end
  end

  module Decisions
    def self.compare(hsh:, sierra_hsh:)
      hsh.extend Compare
      hsh.compare_to(sierra_hsh)
      hsh
    end

    ITYPES = compare(
      hsh: YAML.load_file(File.join(__dir__, '../../data/item_type_lookup.yaml')),
      sierra_hsh: SierraItem.load_itype_descs
    )
  
    LOCS = compare(
      hsh: YAML.load_file(File.join(__dir__, '../../data/item_location_include.yaml')),
      sierra_hsh: SierraItem.load_location_descs
    )
  
    STATUS = compare(
      hsh: YAML.load_file(File.join(__dir__, '../../data/item_status_lookup.yaml')),
      sierra_hsh: SierraItem.load_status_descs
    )
  end
end

  
=begin
  changes = []
  [ITYPES, LOCS, STATUS].each do |decision|
    [decision.removed, decision.added, decision.removed].each do |diff|
      changes << diff unless diff.empty?
    end
  end

  changes
=end