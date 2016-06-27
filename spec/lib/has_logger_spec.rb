require 'spec_helper'
require 'has_logger'

describe HasLogger do
  subject do
    test_class = Class.new do
      include HasLogger
    end
    test_class.new
  end

  describe 'logger' do
    it 'returns a Logger object' do
      expect(subject.logger).to be_a Logger
    end
  end

  describe '#logger=' do
    context 'when given something that is not a Logger object' do
      it 'raises an InvalidLogger error' do
        expect { subject.logger = 'not a logger' }.to raise_error HasLogger::InvalidLogger
      end
    end
  end
end
