# coding: utf-8
#
require 'spec_helper'

describe Picky::Search do
  
  before(:each) do
    @type      = stub :type
    @index     = stub :some_index,
                      :internal_indexed => @type,
                      :each_category    => [],
                      :backend          => Picky::Backends::Memory.new
  end
  
  describe 'tokenized' do
    let(:search) { described_class.new }
    it 'delegates to the tokenizer' do
      tokenizer = stub :tokenizer
      search.stub! :tokenizer => tokenizer
      
      tokenizer.should_receive(:tokenize).once.with(:some_text).and_return [['some_text'], [:some_original]]
      
      search.tokenized :some_text
    end
  end
  
  describe 'boost' do
    let(:search) do
      described_class.new do
        boost [:a, :b] => +3,
              [:c, :d] => -1
      end
    end
    it 'works' do
      search.weights.should == Picky::Query::Weights.new([:a, :b] => 3, [:c, :d] => -1)
    end
  end
  
  describe 'tokenizer' do
    context 'no tokenizer predefined' do
      let(:search) { described_class.new }
      it 'returns the default tokenizer' do
        search.tokenizer.should == Picky::Tokenizer.query_default
      end
    end
    context 'tokenizer predefined' do
      let(:predefined) { stub(:tokenizer, :tokenize => nil) }
      context 'by way of DSL' do
        let(:search) { pre = predefined; described_class.new { searching pre } }
        it 'returns the predefined tokenizer' do
          search.tokenizer.should == predefined
        end
      end
    end
    
  end
  
  describe 'combinations_type_for' do
    before(:each) do
      @blorf  = stub :blorf,  :backend => nil
      @blarf  = stub :blarf,  :backend => nil
      @redis  = stub :redis,  :backend => Picky::Backends::Redis.new
      @memory = stub :memory, :backend => Picky::Backends::Memory.new
    end
    let(:search) { described_class.new }
    it 'returns a specific Combination for a specific input' do
      some_source = stub(:source, :harvest => nil)
      search.combinations_type_for([
        Picky::Index.new(:gu) do
          source some_source
        end]
      ).should == Picky::Query::Combinations::Memory
    end
    it 'just works on the same types' do
      search.combinations_type_for([@blorf, @blarf]).should == Picky::Query::Combinations::Memory
    end
    it 'just uses standard combinations' do
      search.combinations_type_for([@blorf]).should == Picky::Query::Combinations::Memory
    end
    it 'raises on multiple types' do
      expect do
        search.combinations_type_for [@redis, @memory]
      end.to raise_error(Picky::Search::DifferentTypesError)
    end
    it 'raises with the right message on multiple types' do
      expect do
        search.combinations_type_for [@redis, @memory]
      end.to raise_error("Currently it isn't possible to mix Indexes with backends Picky::Backends::Redis and Picky::Backends::Memory in the same Search instance.")
    end
  end
  
  describe "weights handling" do
    it "creates a default weight when no weights are given" do
      search = described_class.new
      
      search.weights.should be_kind_of(Picky::Query::Weights)
    end
    it "handles :weights options when not yet wrapped" do
      search = described_class.new do boost [:a, :b] => +3 end
      
      search.weights.should be_kind_of(Picky::Query::Weights)
    end
    it "handles :weights options when already wrapped" do
      search = described_class.new do boost Picky::Query::Weights.new([:a, :b] => +3) end
      
      search.weights.should be_kind_of(Picky::Query::Weights)
    end
  end
  
  describe "search" do
    before(:each) do
      @search = described_class.new
    end
    it "delegates to search_with correctly" do
      @search.stub! :tokenized => :tokens
      
      @search.should_receive(:search_with).once.with :tokens, 20, 10, :text
      
      @search.search :text, 20, 10
    end
    it "delegates to search_with correctly" do
      @search.stub! :tokenized => :tokens
      
      @search.should_receive(:search_with).once.with :tokens, 20, 0, :text
      
      @search.search :text, 20, 0
    end
    it "uses the tokenizer" do
      @search.stub! :search_with
      
      @search.should_receive(:tokenized).once.with :text
      
      @search.search :text, 20 # (unimportant)
    end
  end
  
  describe 'initializer' do
    context 'with tokenizer' do
      before(:each) do
        tokenizer = stub :tokenizer, :tokenize => [['some_text'], ['some_original']]
        @search = described_class.new @index do
          searching tokenizer
        end
      end
      it 'should return Tokens' do
        @search.tokenized('some text').should be_kind_of(Picky::Query::Tokens)
      end
    end
  end
  
  describe 'to_s' do
    before(:each) do
      @index.stub! :name => :some_index, :each_category => []
    end
    context 'without indexes' do
      before(:each) do
        @search = described_class.new
      end
      it 'works correctly' do
        @search.to_s.should == 'Picky::Search(weights: Picky::Query::Weights({}))'
      end
    end
    context 'with weights' do
      before(:each) do
        @search = described_class.new @index do boost [:a, :b] => +3 end
      end
      it 'works correctly' do
        @search.to_s.should == 'Picky::Search(some_index, weights: Picky::Query::Weights({[:a, :b]=>3}))'
      end
    end
    context 'with special weights' do
      before(:each) do
        class RandomWeights
          def score_for combinations
            rand
          end
          def to_s
            "#{self.class}(rand)"
          end
        end
        @search = described_class.new @index do boost RandomWeights.new end
      end
      it 'works correctly' do
        @search.to_s.should == 'Picky::Search(some_index, weights: RandomWeights(rand))'
      end
    end
    context 'without weights' do
      before(:each) do
        @search = described_class.new @index
      end
      it 'works correctly' do
        @search.to_s.should == 'Picky::Search(some_index, weights: Picky::Query::Weights({}))'
      end
    end
  end

end