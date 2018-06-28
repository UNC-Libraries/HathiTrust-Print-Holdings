require_relative '../lib/hathi_print_holdings.rb'

class SierraItem
  attr_reader :exclude_message

  def set_rec_data(hsh)
    @rec_data = hsh
  end

  def set_varfields(hsh)
    @varfields = hsh
  end

  def set_htbnum(bnum)
    @ht_bnum = bnum
  end

end

RSpec.describe SierraItem do
  before :each do
    @item = SierraItem.new('i1000001a')
    @item.set_htbnum('b1000001')
  end

  describe '#fed_doc_location?' do

    context 'when dcpf' do
      it 'returns true' do
        @item.set_rec_data(location_code: 'dcpf')
        expect(@item.fed_doc_location?).to be true
      end
    end

    context 'when dcpf9' do
      it 'returns true' do
        @item.set_rec_data(location_code: 'dcpf9')
        expect(@item.fed_doc_location?).to be true
      end
    end

    context 'when vapa' do
      it 'returns true' do
        @item.set_rec_data(location_code: 'vapa')
        expect(@item.fed_doc_location?).to be true
      end
    end

    context 'when anything else' do
      it 'returns nil' do
        @item.set_rec_data(location_code: 'ddda')
        expect(@item.fed_doc_location?).to be_nil
      end
    end


  end

  describe '#condition' do

    context 'when self.brittle?, e.g location = trbrs' do
      it 'returns BRT' do
        @item.set_rec_data(location_code: 'trbrs')
        expect(@item.condition).to eq('BRT')
      end
    end

    context 'when not self.brittle?' do
      it 'returns nil' do
        @item.set_rec_data(location_code: 'ddda')
        expect(@item.condition).to be_nil
      end
    end
  end

  describe '#brittle?' do
    context 'when location = trbrs' do
      it 'returns true' do
        @item.set_rec_data(location_code: 'trbrs')
        expect(@item.brittle?).to be true
      end
    end

    context 'when item_message_code = d' do
      it 'returns true' do
        @item.set_rec_data(item_message_code: 'd')
        expect(@item.brittle?).to be true
      end
    end

    context 'when internal note includes brittle' do
      it 'returns true' do
        @item.set_varfields('x' => [{field_content: 'I am brittle'}])
        expect(@item.brittle?).to be true
      end

      it 'internal note is case-insensitive' do
        @item.set_varfields('x' => [{field_content: 'I am BrItTlE'}])
        expect(@item.brittle?).to be true
      end
    end

    context 'when no other criteria are met' do
      context 'and location is not trbrs' do
        it 'returns nil' do
          @item.set_rec_data(location_code: 'ddda')
          expect(@item.brittle?).to be_nil
        end
      end

      context 'and item_message_code is not d' do
        it 'returns nil' do
          @item.set_rec_data(item_message_code: 'a')
          expect(@item.fed_doc_location?).to be_nil
        end
      end

      context 'and no brittle internal note' do
        it 'returns nil' do
          @item.set_varfields('n' => [{field_content: 'I am in good shape'}])
          expect(@item.brittle?).to be_nil
        end
      end
    end
  end


  describe '#invalid_icode2?' do
      
    # example invalid codes
    %w[a c 3].each do |code|
      context "when icode is: \'#{code}\'" do
        before :each do
          @item.set_rec_data(icode2: code)
          @message = ['b1000001', 'i1000001', 'Invalid item code 2', code]
        end

        it 'returns true' do
          expect(@item.invalid_icode2?).to be true
        end

        it 'sets exclude message' do
          @item.invalid_icode2?
          expect(@item.exclude_message).to eq(@message)
        end
      end
    end

    # all valid codes
    (%w[n b l t -] + ["", " "]).each do |code|
      context "when icode is: \'#{code}\'" do
        before :each do
          @item.set_rec_data(icode2: code)
          @message = ['b1000001', 'i1000001', 'Invalid item code 2', code]
        end

        it 'returns false' do
          expect(@item.invalid_icode2?).to be false
        end

        it 'does not set exclude message' do
          @item.invalid_icode2?
          expect(@item.exclude_message).to be_nil
        end
      end
    end
  end

  describe '#ineligible_icode2?' do

    # all ineligible codes
    %w[t].each do |code|
      context "when icode is: \'#{code}\'" do
        before :each do
          @item.set_rec_data(icode2: code)
          @message = ['b1000001', 'i1000001', 'Ineligible item code 2', code]
        end

        it 'returns true' do
          expect(@item.ineligible_icode2?).to be true
        end

        it 'sets exclude message' do
          @item.ineligible_icode2?
          expect(@item.exclude_message).to eq(@message)
        end
      end
    end

    # example eligible codes
    (%w[n b l -] + ["", " "]).each do |code|
      context "when icode is: \'#{code}\'" do
        before :each do
          @item.set_rec_data(icode2: code)
          @message = ['b1000001', 'i1000001', 'Ineligible item code 2', code]
        end

        it 'returns false' do
          expect(@item.ineligible_icode2?).to be false
        end

        it 'does not set exclude message' do
          @item.ineligible_icode2?
          expect(@item.exclude_message).to be_nil
        end
      end
    end
  end

  describe '#invalid_itype?' do

    # example invalid codes
    %w[300 490 99].each do |code|
      context "when itype is: \'#{code}\'" do
        before :each do
          @item.set_rec_data(itype_code_num: code)
          @message = ['b1000001', 'i1000001', 'Invalid item type', code]
        end

        it 'returns true' do
          expect(@item.invalid_itype?).to be true
        end

        it 'sets exclude message' do
          @item.invalid_itype?
          expect(@item.exclude_message).to eq(@message)
        end
      end
    end

    # example valid codes
    %w[0 1 2 86 116].each do |code|
      context "when itype is: \'#{code}\'" do
        before :each do
          @item.set_rec_data(itype_code_num: code)
          @message = ['b1000001', 'i1000001', 'Invalid item type', code]
        end

        it 'returns false' do
          expect(@item.invalid_itype?).to be false
        end

        it 'does not set exclude message' do
          @item.invalid_itype?
          expect(@item.exclude_message).to be_nil
        end
      end
    end
  end

  describe '#ineligible_itype?' do

    # example ineligible codes
    %w[4 5 6 86 116].each do |code|
      context "when itype is: \'#{code}\'" do
        before :each do
          @item.set_rec_data(itype_code_num: code)
          @message = ['b1000001', 'i1000001', 'Ineligible item type', code]
        end

        it 'returns true' do
          expect(@item.ineligible_itype?).to be true
        end

        it 'sets exclude message' do
          @item.ineligible_itype?
          expect(@item.exclude_message).to eq(@message)
        end
      end
    end

    # example eligible codes
    %w[0 1 2 83].each do |code|
      context "when itype is: \'#{code}\'" do
        before :each do
          @item.set_rec_data(itype_code_num: code)
          @message = ['b1000001', 'i1000001', 'Ineligible item type', code]
        end

        it 'returns false' do
          expect(@item.ineligible_itype?).to be false
        end

        it 'does not set exclude message' do
          @item.ineligible_itype?
          expect(@item.exclude_message).to be_nil
        end
      end
    end
  end

  describe '#ineligible_location?' do

    context 'when location is not included in yaml' do
      it 'is considered eligible' do
        @item.set_rec_data(location_code: 'unknown_loc_code')
        expect(@item.ineligible_location?).to be false
      end
    end

    # example ineligible codes
    %w[aadaa ebnb uadai].each do |code|
      context "when location is: \'#{code}\'" do
        before :each do
          @item.set_rec_data(location_code: code)
          @message = ['b1000001', 'i1000001', 'Ineligible item location', code]
        end

        it 'returns true' do
          expect(@item.ineligible_location?).to be true
        end

        it 'sets exclude message' do
          @item.ineligible_location?
          expect(@item.exclude_message).to eq(@message)
        end
      end
    end

    # example eligible codes
    %w[ddda ddz nohh].each do |code|
      context "when location is: \'#{code}\'" do
        before :each do
          @item.set_rec_data(location_code: code)
          @message = ['b1000001', 'i1000001', 'Ineligible item location', code]
        end

        it 'returns false' do
          expect(@item.ineligible_location?).to be false
        end

        it 'does not set exclude message' do
          @item.ineligible_location?
          expect(@item.exclude_message).to be_nil
        end
      end
    end
  end
end