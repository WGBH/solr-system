unless ARGV.count == 1
  puts("USAGE: #{$PROGRAM_NAME} mikes.csv > config/redirect_map.yml")
  exit 1
end
while gets
  # This works for the data we have, but
  # is NOT a general-purpose CSV parser.
  fedora, pretty, _artesia, ov3 = $LAST_READ_LINE.strip.gsub('"', '').split(',')
  next unless ov3 && ov3 != ''
  puts "\"/catalog/#{fedora}\": \"/catalog/#{ov3}\""
  puts "\"/catalog/#{pretty}\": \"/catalog/#{ov3}\"" if pretty != ''
end
