#!/usr/bin/env ruby

require 'uri'
require 'fileutils'
require 'nokogiri'
require 'open-uri'
require 'json'
require 'pry'

FileUtils.mkdir_p 'test'

def import_youtube_page
  content = ''
  File.open('test/youtube.html', 'w') do |f|
    puts 'Downloading youtube page...'
    page_url = ARGV[0] || 'http://www.youtube.com/watch?v=Gq76bcxM_gI'
    content = open(page_url).read
    puts 'Downloaded!'
    f.write content
    puts 'Written to youtube.html!'
  end
  content
end

html = Nokogiri::HTML(import_youtube_page)
str = html.at_css('#player-api').next_element.next_element.content[48..-2]
# binding.pry
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

File.open('test/url_encoded_fmt_stream_map.json', 'w') do |f|
  arr = []
  ytconfig['args']['url_encoded_fmt_stream_map'].split(',').each do |i|
    h = Hash[URI.decode_www_form(i)]

    url_query = Hash[URI.decode_www_form(URI.parse(h['url']).query)]
    h['url_query'] = url_query
    h['url_query_key_size'] = url_query.keys.size

    signature = h['sig']
    h['download_url'] = h['url'] + '&' + URI.encode_www_form([['signature', signature]])
    arr << h
  end
  f.puts JSON.pretty_generate(arr)
end

# youtube adaptive bitrate streaming encoding
File.open('test/adaptive_fmts.json', 'w') do |f|
  arr = []
  ytconfig['args']['adaptive_fmts'].split(',').each do |i|
    h = Hash[URI.decode_www_form(i)]
    url_query = Hash[URI.decode_www_form(URI.parse(h['url']).query)]
    h['url_query'] = url_query
    h['url_query_key_size'] = url_query.keys.size
    arr << h
  end
  f.puts JSON.pretty_generate(arr)
end

# `curl -o \"foo.flv\" -L -A \"#{USER_AGENT}\" \"#{url}\"`
