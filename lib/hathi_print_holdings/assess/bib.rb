module HathiPrintHoldings
  module Assess
    class Bib
      include HathiPrintHoldings::Writing

      attr_reader :bnum

      def initialize(bib)
        @bib = bib
        @htbnum = @bib.bnum_trunc
        @marc = @bib.marc
      end

      def oclcnum
        @bib.oclcnum
      end

      # Govdoc when code = 1
      # 1 if an 074$a exists, even an empty 074$a, or when a monograph with
      # any item in a fed doc location
      def ht_govdoc_code
        @ht_govdoc_code ||=
          if @bib.any_fields?(tag: '074', complex_subfields: [[:has, code: 'a']])
            1
          elsif ht_category == 'serial'
            0
          elsif eligible_items.any? { |i| i.fed_doc_location? }
            1
          else
            0
          end
      end

      def ht_category
        case @bib.blvl
        when 's'
          'serial'
        when 'c', 'i', 'm'
          if eligible_items&.count == 1 || volumes&.uniq&.count == 1
            'sv mono'
          elsif volumes.empty? || volumes.uniq.count > 1
            'mv mono'
          else
            write_warn(
              [@htbnum, nil, 'Possible trouble counting unique vol designations', '']
            )
          end
        end
      end

      # returns one 022a if it exists
      def ht_issn
      @marc.field_find(
        tag: '022', complex_subfields: [[:has, code: 'a']]
      )['a'].strip
      rescue NoMethodError
        nil
      end

      def eligible_items
        return @eligible_items if @eligible_items
        eligible_items = @bib.items&.select { |i| i.eligible?(@htbnum) }
        eligible_items = nil if eligible_items.empty?
        @eligible_items = eligible_items
      end

      def volumes
        return [] unless eligible_items
        eligible_items.map{ |i| i.volumes.map(&:strip) || [''] }
      end

      #
      # Exclusion
      #

      def eligible?
        return @eligible unless @eligible.nil?
        @eligible = true
        if
            # Check for certain values in 915
            ineligible_915? ||

            # Check for certain values in 919
            ineligible_919? ||

            # Check for OCLC number
            no_oclcnum? ||

            # Check for archival control in leader
            archival_control? ||

            # Check for invalid/ineligible blvl
            invalid_blvl? ||
            ineligible_blvl? ||

            # Check for indications of microform format in bib record
            microform_gmd? ||
            microform_338? ||
            microform_007? ||

            # Check for invalid/ineligible rec_type
            invalid_rectype? ||
            ineligible_rectype? ||

            # Check physical description terms
            no_eligible_300a? ||

            # Exclude unless attached items or holdings records
            no_holdings_or_items? ||

            # also exclude monos with no items
            (ht_category != 'serial' && no_items?)
          
          write_exclude(@exclude_message)
          @eligible = false
        end
        @eligible
      end

      #
      # Exclusion criteria
      #

      #check for certain values in 915
      #BROWSE = leased print books
      # true if any 915 ~* BROWSE
      # sets exclude_message including field_content causing exclusion
      def ineligible_915?
        bad_field = @marc.field_find(tag: '915', value: /BROWSE/i)
        return false unless bad_field
        @exclude_message = [@htbnum, nil, 'Ineligible based on 915 value',
                            bad_field.field_content]
        true
      end

      #check for certain values in 919
      #dwsgpo = online gov docs, many otherwise coded as print
      # true if any 915 ~* dwsgpo
      # sets exclude_message including field_content causing exclusion
      def ineligible_919?
        bad_field = @marc.field_find(tag: '919', value: /dwsgpo/i)
        return false unless bad_field
        @exclude_message = [@htbnum, nil, 'Ineligible based on 919 value',
                            bad_field.field_content]
        true
      end

      def no_oclcnum?
        return false if oclcnum
        @exclude_message = [@htbnum, nil, 'No OCLC number', nil]
        true
      end

      #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
      #check for archival control in leader
      #exclude records coded a - HT doesn't want records for archival
      #collections
      #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
      def archival_control?
        if @bib.ctrl_type == 'a'
          @exclude_message = [@htbnum, nil, 'Archival control', nil]
          return true
        end
        false
      end

      def invalid_blvl?
        if @marc.ldr07_invalid?
          @exclude_message = [@htbnum, nil, 'Invalid blvl in LDR', @bib.blvl]
          return true
        end
        false
      end

      def ineligible_blvl?
        unless @bib.blvl =~ /[cims]/
          @exclude_message = [@htbnum, nil, 'Ineligible blvl from LDR', @bib.blvl]
          return true
        end
        false
      end

        #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
        #check for indications of microform format in bib record
        #-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
      def microform_gmd?
        if @marc.any_fields?(tag: '245', value: /\|h\s*\[micro/i)
          @exclude_message = [@htbnum, nil, 'Microform GMD', nil]
          return true
        end
        false
      end

      def microform_338?
        regexp = /aperture card|micro(fiche|film|opaque)/i
        if @marc.any_fields?(tag: '338', value: regexp)
          @exclude_message = [@htbnum, nil, 'Microform 338', nil]
          return true
        end
        false
      end

      def microform_007?
        if @marc.any_fields?(tag: '007', value: /^h/ )
          @exclude_message = [@htbnum, nil, 'Microform 007', nil]
          return true
        end
        false
      end

      def invalid_rectype?
        if @marc.ldr06_invalid?
          @exclude_message = [
            @htbnum, nil, 'Invalid record type (from LDR)', @bib.rec_type
          ]
          return true
        end
        false
      end

      def ineligible_rectype?
        unless @bib.rec_type =~ /[acdept]/
          @exclude_message = [
            @htbnum, nil, 'Ineligible record type (from LDR)', @bib.rec_type
          ]
          return true
        end
        false
      end

      def no_eligible_300a?
        regexp = /box|item|pamphlet|piece|sheet/i
        no_eligible = @marc.no_fields?(
          tag: '300',
          complex_subfields: [[:has_as_first, code: 'a', value_not: regexp]]
        )
        if no_eligible
          bad_content = @marc.fields('300').first['a']
          @exclude_message = [@htbnum, nil, 'Physical description', bad_content]
          return true
        end
        false
      end

      def no_holdings_or_items?
        unless @bib.items || @bib.holdings
          @exclude_message = [@htbnum, nil, 'No items or holdings attached', nil]
          return true
        end
        false
      end

      # only used for monos
      def no_items?
        unless @bib.items
          @exclude_message = [@htbnum, nil, 'No attached items', nil]
          return true
        end
      end
      false
    end
  end
end