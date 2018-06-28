require_relative '../../lib/hathi_print_holdings.rb'


class HathiPrintHoldings::Assess::Bib
  attr_reader :exclude_message
end

class SierraBib

  def set_rec_data(hsh)
    @rec_data = hsh
  end

  def set_varfield_data(hsh)
    @varfield_data = hsh
  end

  def set_ldr(hsh)
    @ldr_data = hsh
  end

end

RSpec.describe HathiPrintHoldings::Assess::Bib do
  let(:bib) { SierraBib.new('b1000001a') }
  let(:ht)  { HathiPrintHoldings::Assess::Bib.new(bib) }

  describe '#ht_govdoc_code' do
  end

  describe '#ht_category' do

    context 'when leader blvl is s' do
      it 'returns serial' do
      end
    end

    context 'when leader blvl in: c, i, m' do
      context 'and eligible item count is 1' do
      end

      context 'and uniq volumes count is 1' do
      end
      
      context 'and uniq volumes count > 1' do
      end
    end
  end

  describe '#ht_issn' do
  end

  describe '#eligible_items' do
  end

  describe '#volumes' do
  end

  describe '#ineligible_915?' do
    context 'when 915 includes BROWSE' do
      it 'returns true' do
        bib.set_varfield_data([marc_tag: '915', field_content: 'browse'])
        expect(ht.ineligible_915?).to be true
      end

      it 'BROWSE detection is case-insensitive' do
        bib.set_varfield_data([marc_tag: '915', field_content: 'BRowSE'])
        expect(ht.ineligible_915?).to be true
      end

      it 'sets exclude message' do
        bib.set_varfield_data([marc_tag: '915', field_content: 'browse'])
        message = ['b1000001', nil, 'Ineligible based on 915 value', 'browse']
        ht.ineligible_915?
        expect(ht.exclude_message).to eq(message)
      end
    end

    context 'when no 915 that contains BROWSE' do
      it 'returns false' do
        bib.set_varfield_data([marc_tag: '915', field_content: 'eligible'])
        expect(ht.ineligible_915?).to be false
      end

      it 'does not set exclude message' do
        bib.set_varfield_data([marc_tag: '915', field_content: 'eligible'])
        ht.ineligible_915?
        expect(ht.exclude_message).to be_nil
      end
    end
  end

  describe '#ineligible_919?' do
    context 'when 919 includes dwsgpo' do
      it 'returns true' do
        bib.set_varfield_data([marc_tag: '919', field_content: 'dwsgpo'])
        expect(ht.ineligible_919?).to be true
      end

      it 'dwsgpo detection is case-insensitive' do
        bib.set_varfield_data([marc_tag: '919', field_content: 'DWsgPo'])
        expect(ht.ineligible_919?).to be true
      end

      it 'sets exclude message' do
        bib.set_varfield_data([marc_tag: '919', field_content: 'dwsgpo'])
        message = ['b1000001', nil, 'Ineligible based on 919 value', 'dwsgpo']
        ht.ineligible_919?
        expect(ht.exclude_message).to eq(message)
      end
    end

    context 'when no 919 that contains dwsgpo' do
      it 'returns false' do
        bib.set_varfield_data([marc_tag: '919', field_content: 'eligible'])
        expect(ht.ineligible_919?).to be false
      end

      it 'does not set exclude message' do
        bib.set_varfield_data([marc_tag: '919', field_content: 'eligible'])
        ht.ineligible_919?
        expect(ht.exclude_message).to be_nil
      end
    end
  end

  describe '#archival_control?' do
    context 'bib control type is "a"' do
      it 'returns true' do
        bib.set_ldr(control_type_code: 'a')
        expect(ht.archival_control?).to be true
      end

      it 'sets exclude message' do
        bib.set_ldr(control_type_code: 'a')
        message = ['b1000001', nil, 'Archival control', nil]
        ht.archival_control?
        expect(ht.exclude_message).to eq(message)
      end
    end

    context 'bib control type is not "a"' do
      it 'returns false' do
        bib.set_ldr(control_type_code: 'b')
        expect(ht.archival_control?).to be false
      end

      it 'considers control type = nil to be "not a"' do
        bib.set_ldr({})
        expect(ht.archival_control?).to be false
      end

      it 'does not set exclude message' do
        bib.set_ldr(control_type_code: 'b')
        ht.archival_control?
        expect(ht.exclude_message).to be_nil
      end
    end
  end

  describe '#ineligible_blvl' do
    #
    #
  end

  describe '#microform_gmd?' do
  end

  describe '#microform_338?' do
    terms = ['aperture card', 'microfiche', 'microfilm', 'microopaque']
    terms.each do |term|
      context "when 338 includes #{term}" do
        it 'returns true' do
          bib.set_varfield_data([marc_tag: '338', field_content: term])
          expect(ht.microform_338?).to be true
        end

        it 'detection is case insensitive' do
          bib.set_varfield_data([marc_tag: '338', field_content: term.upcase])
          expect(ht.microform_338?).to be true
        end

        it 'sets exclude message' do
          bib.set_varfield_data([marc_tag: '338', field_content: term])
          message = ['b1000001', nil, 'Microform 338', nil]
          ht.microform_338?
          expect(ht.exclude_message).to eq(message)
        end
      end
    end
    context "when no 338 includes terms" do
      it 'returns false' do
        bib.set_varfield_data([marc_tag: '338', field_content: 'eligible'])
        expect(ht.microform_338?).to be false
      end

      it 'does not set exclude message' do
        bib.set_varfield_data([marc_tag: '338', field_content: 'eligible'])
        ht.microform_338?
        expect(ht.exclude_message).to be_nil
      end
    end
  end

  describe '#microform_007?' do
  end

  describe '#ineligible_rectype?' do
    #
    #
    #
  end

  describe '#ineligible_300a_terms?' do
    terms = %w[box item pamphlet piece sheet]
    terms.each do |term|
      context "when 300a includes '#{term}'" do
        it 'returns true' do
          bib.set_varfield_data(
            [marc_tag: '300', field_content: "|a blah #{term}"]
          )
          expect(ht.ineligible_300a_terms?).to be true
        end

        it 'detection is case insensitive' do
          bib.set_varfield_data(
            [marc_tag: '300', field_content: "|a blah #{term.upcase}"]
          )
          expect(ht.ineligible_300a_terms?).to be true
        end

        it 'sets exclude message' do
          bib.set_varfield_data(
            [marc_tag: '300', field_content: "|a blah #{term}"]
          )
          message = ['b1000001', nil, 'Physical description', " blah #{term}"]
          ht.ineligible_300a_terms?
          expect(ht.exclude_message).to eq(message)
        end

        it 'exclude message details contain entire subfield a' do
          bib.set_varfield_data(
            [marc_tag: '300', field_content: "|a blah #{term}"]
          )
          ht.ineligible_300a_terms?
          expect(ht.exclude_message.last).to eq(" blah #{term}")
        end
      end

      context 'when term is in a 300 but not $a' do
        it 'returns false' do
          bib.set_varfield_data(
            [marc_tag: '300', field_content: "|afine |b blah #{term}"]
          )
          expect(ht.ineligible_300a_terms?).to be false
        end
      end
    end

    context "when no 338 includes terms" do
      it 'returns false' do
        bib.set_varfield_data([marc_tag: '300', field_content: '|aeligible'])
        expect(ht.ineligible_300a_terms?).to be false
      end

      it 'does not set exclude message' do
        bib.set_varfield_data([marc_tag: '300', field_content: '|aeligible'])
        ht.ineligible_300a_terms?
        expect(ht.exclude_message).to be_nil
      end
    end
  end

  describe '#no_holdings_or_items?' do
  end

  describe '#no_items?' do
  end

end