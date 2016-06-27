require_relative '../../scripts/lib/pb_core_ingester'

describe PBCoreIngester do
  it 'ingests fixtures' do
    expect { PBCoreIngester.load_fixtures }.not_to raise_error
  end
end
