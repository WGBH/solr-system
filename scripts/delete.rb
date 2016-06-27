require 'rsolr'

fail('Requires one argument') unless ARGV.count == 1
id = ARGV.shift
fail('Not expected format') unless id =~ /^[AVI]_[0-9A-F]{32}$/

RSolr.connect(url: 'http://localhost:8983/solr/').tap do |rsolr|
  puts rsolr.delete_by_id(id)
  puts rsolr.commit
end
