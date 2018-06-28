module HathiPrintHoldings
  module Assess
    class Bib
      include HathiPrintHoldings::Writing

      attr_reader :bnum

      def initialize(bib)
        @bib = bib
        @htbnum = @bib.bnum_trunc
      end

      def oclcnum
        @bib.oclcnum
      end

      # Govdoc when code = 1
      # 1 if an 074$a exists, even an empty 074$a, or when a monograph with
      # any item in a fed doc location
      def ht_govdoc_code
        @ht_govdoc_code ||=
          if @bib.varfield('074')&.any? { |v| v[:field_content] =~ /\|a/ }
            1
          elsif self.ht_category == 'serial'
            0
          elsif self.eligible_items.any? { |i| i.fed_doc_location? }
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
          if self.eligible_items&.count == 1 || self.volumes&.uniq&.count == 1
            'sv mono'
          elsif self.volumes.empty? || self.volumes.uniq.count > 1
            'mv mono'
          else
            self.write_warn(
              [@htbnum, nil, 'Possible trouble counting unique vol designations', '']
            )
          end
        end
      end

      # returns one 022a if it exists
      def ht_issn
        m022_with_sfa = @bib.varfield('022')&.select { |v| v[:field_content] =~ /\|a/ }
        return nil if !m022_with_sfa || m022_with_sfa.empty?
        @bib.subfield_from_field_content('a', m022_with_sfa.first[:field_content]).strip
      end

      def eligible_items
        return @eligible_items if @eligible_items
        eligible_items = @bib.items&.select { |i| i.eligible?(@htbnum) }
        eligible_items = nil if eligible_items.empty?
        @eligible_items = eligible_items
      end

      def volumes
        return [] unless self.eligible_items
        self.eligible_items.map{ |i| i.volumes.map(&:strip) || [''] }
      end

      #
      # Exclusion
      #

      def eligible?
        return @eligible unless @eligible.nil?
        @eligible = true
        if
            # Check for certain values in 915
            self.ineligible_915? ||

            # Check for certain values in 919
            self.ineligible_919? ||

            # Check for OCLC number
            self.no_oclcnum? ||

            # Check for archival control in leader
            self.archival_control? ||

            # Check for invalid/ineligible blvl
            self.invalid_blvl? ||
            self.ineligible_blvl? ||

            # Check for indications of microform format in bib record
            self.microform_gmd? ||
            self.microform_338? ||
            self.microform_007? ||

            # Check for invalid/ineligible rec_type
            self.invalid_rectype? ||
            self.ineligible_rectype? ||

            # Check physical description terms
            self.ineligible_300a_terms? ||

            # Exclude unless attached items or holdings records
            self.no_holdings_or_items? ||

            # also exclude monos with no items
            (self.ht_category != 'serial' && self.no_items?)
          
          self.write_exclude(@exclude_message)
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
        @bib.varfield('915')&.each do  |f|
          if f[:field_content] =~ /BROWSE/i
            @exclude_message = [
              @htbnum, nil, 'Ineligible based on 915 value', f[:field_content]
            ]
            return true
          end
        end
        false
      end

      #check for certain values in 919
      #dwsgpo = online gov docs, many otherwise coded as print
      # true if any 915 ~* dwsgpo
      # sets exclude_message including field_content causing exclusion
      def ineligible_919?
        @bib.varfield('919')&.each do |f|
          if f[:field_content] =~ /dwsgpo/i
            @exclude_message = [
              @htbnum, nil, 'Ineligible based on 919 value', f[:field_content]
            ]
            return true
          end
        end
        false
      end

      def no_oclcnum?
        unless self.oclcnum
          @exclude_message = [@htbnum, nil, 'No OCLC number', nil]
          return true
        end
        false
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
        unless @bib.blvl =~ /[abcdims]/
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
        if @bib.varfield('245')&.any? { |f| f[:field_content] =~ /\|h\s*\[micro/i }
          @exclude_message = [@htbnum, nil, 'Microform GMD', nil]
          return true
        end
        false
      end

      def microform_338?
        regexp = /aperture card|micro(fiche|film|opaque)/i
        if @bib.varfield('338')&.any? { |f| f[:field_content] =~ regexp }
          @exclude_message = [@htbnum, nil, 'Microform 338', nil]
          return true
        end
        false
      end

      def microform_007?
        if @bib.m007s&.any? { |f| f =~ /^h/ }
          @exclude_message = [@htbnum, nil, 'Microform 007', nil]
          return true
        end
        false
      end

      def invalid_rectype?
        unless @bib.rec_type =~ /[acdefgijkmoprt]/
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

      def ineligible_300a_terms?
        m300_with_sfa = @bib.varfield('300')
        return false unless m300_with_sfa
        regexp = /
          \|a([^\|]*                          # intial content of a 300a
          (?:box|item|pamphlet|piece|sheet)   # ineligible terms
          [^\|]*)                             # remaining content of the 300a
                                              # captured entire matching 300a
        /ix                                   #
        m300_with_sfa.each do |f|
          m = f[:field_content].match(regexp)
          next unless m
          @exclude_message = [@htbnum, nil, 'Physical description', m[1]]
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