#!/usr/bin/env ruby

require 'bundler/setup'
require 'uri'
require 'fileutils'
require 'nokogiri'
require 'open-uri'
require 'json'
require 'pry'

USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/29.0.1547.76 Safari/537.36"
FileUtils.mkdir_p 'test'

def import_youtube_page
  # content = ''
  # File.open('test/youtube.html', 'w') do |f|
  #   puts 'Downloading youtube page...'
  #   page_url = ARGV[0] || 'http://www.youtube.com/watch?v=Gq76bcxM_gI'
  #   content = open(page_url).read
  #   puts 'Downloaded!'
  #   f.write content
  #   puts 'Written to youtube.html!'
  # end
  # content

  puts 'Downloading youtube page...'
  page_url = ARGV[0] || 'http://www.youtube.com/watch?v=Gq76bcxM_gI'
  system("curl -A #{USER_AGENT} -D test/header.txt -c test/cookie.txt -o test/youtube.html #{page_url}")
  puts 'Written to youtube.html!'
  File.read('test/youtube.html')
end

html = Nokogiri::HTML(import_youtube_page)
str = html.at_css('#player-api').next_element.next_element.content[48..-2]
begin
  ytconfig = JSON.parse(str)
  File.open('test/ytconfig.json', 'w') do |f|
    f.puts JSON.pretty_generate(ytconfig)
  end
rescue JSON::ParserError
  raise "invalid json"
end

File.open('test/fmt_list.json', 'w') do |f|
  arr = []
  ytconfig['args']['fmt_list'].split(',').each do |line|
    arr << line
  end
  f.puts JSON.pretty_generate(arr)
end

normal_fmts = []
ytconfig['args']['url_encoded_fmt_stream_map'].split(',').each do |i|
  h = Hash[URI.decode_www_form(i)]
  url_query = Hash[URI.decode_www_form(URI.parse(h['url']).query)]
  h['url_query'] = url_query
  h['url_query_key_size'] = url_query.keys.size
  signature = h['sig']
  h['download_url'] = h['url'] + '&' + URI.encode_www_form([['signature', signature]])
  normal_fmts << h
end
File.open('test/normal_fmts.json', 'w') do |f|
  f.puts JSON.pretty_generate(normal_fmts)
end

# youtube adaptive bitrate streaming encoding
adaptive_fmts = []
ytconfig['args']['adaptive_fmts'].split(',').each do |i|
  h = Hash[URI.decode_www_form(i)]
  url_query = Hash[URI.decode_www_form(URI.parse(h['url']).query)]
  h['url_query'] = url_query
  h['url_query_key_size'] = url_query.keys.size
  adaptive_fmts << h
end
File.open('test/adaptive_fmts.json', 'w') do |f|
  f.puts JSON.pretty_generate(adaptive_fmts)
end

target = normal_fmts[1]['download_url']
puts target
system("curl", "-A", USER_AGENT, "-b", "test/cookie.txt", "-o", "test/youtube1.mp4", target)
# system("wget", "-Ncq", "-e", "convert-links=off", "--load-cookies", "/dev/null", "--tries=200", "--timeout=20", "--no-check-certificate", "-O", "test/youtube2.mp4", target);
