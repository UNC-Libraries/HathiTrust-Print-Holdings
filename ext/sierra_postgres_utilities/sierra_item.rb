require_relative '../../lib/hathi_print_holdings.rb'

class SierraItem
  include HathiPrintHoldings::Writing

  def fed_doc_location?
    true if %w[dcpf dcpf9 vapa].include?(self.location_code)
  end

  def holding_status
    hstatus = HathiPrintHoldings::Decisions::STATUS[self.status_code]
    if hstatus
      hstatus = hstatus['val']
    else
      hstatus = 'CH'
      self.write_warn(
        [@ht_bnum, self.inum_trunc, 'Invalid item status', self.status_code]
      )
    end
    hstatus
  end

  def condition
    'BRT' if self.brittle?
  end

  def brittle?
    if (self.location_code == 'trbrs' ||
        self.rec_data[:item_message_code] == 'd'      ||
        self.internal_notes&.any? { |n| n =~ /brittle/i })
      return true
    end
  end

  #
  # Exclusion
  #

  def eligible?(bib_bnum)
    return @eligible unless @eligible.nil?
    @eligible = true
    @ht_bnum = bib_bnum
    if  self.invalid_icode2?    ||
        self.ineligible_icode2? ||
        self.invalid_itype?     ||
        self.ineligible_itype?  ||
        self.ineligible_location?
      self.write_exclude(@exclude_message)
      @eligible = false
    end
    @eligible
  end

  #
  # Exclusion criteria
  #

  def invalid_icode2?
    unless self.icode2 =~ /[ nblt-]/ || self.icode2 == ''
      @exclude_message = [@ht_bnum, self.inum_trunc, 'Invalid item code 2', self.icode2]
      return true
    end
    false
  end

  def ineligible_icode2?
    if self.icode2 == 't'
      @exclude_message = [@ht_bnum, self.inum_trunc, 'Ineligible item code 2', self.icode2]
      return true
    end
    false
  end

  def invalid_itype?
    unless HathiPrintHoldings::Decisions::ITYPES.include?(self.itype_code)
      @exclude_message = [@ht_bnum, self.inum_trunc, 'Invalid item type', self.itype_code]
      return true
    end
    false
  end

  def ineligible_itype?
    unless HathiPrintHoldings::Decisions::ITYPES[self.itype_code]['val'] == 'y'
      @exclude_message = [@ht_bnum, self.inum_trunc, 'Ineligible item type', self.itype_code]
      return true
    end
    false
  end

  def ineligible_location?
    return false unless HathiPrintHoldings::Decisions::LOCS[self.location_code]
    if HathiPrintHoldings::Decisions::LOCS[self.location_code]['val'] == 'n'
      @exclude_message = [
        @ht_bnum, self.inum_trunc, 'Ineligible item location', self.location_code
      ]
      return true
    end
    false
  end
end
