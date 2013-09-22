#!/usr/bin/env ruby

require 'bundler/setup'
require 'uri'
require 'fileutils'
require 'nokogiri'
require 'json'
require 'pry'

FileUtils.mkdir_p 'tmp'

PAGE_URL = ARGV[0] || 'http://www.youtube.com/watch?v=Gq76bcxM_gI'
USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/29.0.1547.76 Safari/537.36"

def fetch_youtube_page
  puts "Downloading youtube page #{PAGE_URL} ..."
  system("curl", "-A", USER_AGENT, "-c", "tmp/cookie.txt", "-o", "tmp/youtube.html", PAGE_URL)
  puts 'Page written to tmp/youtube.html!'
  File.read('tmp/youtube.html')
end

puts "Analyzing youtube page #{PAGE_URL} ..."
html = Nokogiri::HTML(fetch_youtube_page)
ytconfig = JSON.parse(html.at_css('#player-api').next_element.next_element.content[48..-2])
File.open('tmp/ytconfig.json', 'w') do |f|
  f.puts JSON.pretty_generate(ytconfig)
end

fmt_list = []
ytconfig['args']['fmt_list'].split(',').each do |line|
  fmt_list << line
end
File.open('tmp/fmt_list.json', 'w') do |f|
  f.puts JSON.pretty_generate(fmt_list)
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
File.open('tmp/normal_fmts.json', 'w') do |f|
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
File.open('tmp/adaptive_fmts.json', 'w') do |f|
  f.puts JSON.pretty_generate(adaptive_fmts)
end

d_index = nil
loop do
  puts "Which format do you want to download?"
  normal_fmts.each_with_index do |fmt, i|
    puts "#{i.to_s.ljust(2)}, #{fmt['quality'].to_s.ljust(10)}, #{fmt['type'].to_s.ljust(50)}"
  end
  puts "Please type in the index:"
  d_index = STDIN.gets.chomp.to_i
  if normal_fmts.size > d_index and d_index >= 0
    break
  else
    puts "Invalid index!"
  end
end

target = normal_fmts[d_index]['download_url']
target_extension = case normal_fmts[d_index]['type']
                   when /webm/i
                     'webm'
                   when /mp4/i
                     'mp4'
                   when /flv/i
                     'flv'
                   when /3gpp/i
                     '3gp'
                   else
                     raise 'unknown video type!'
                   end
puts "Start downloading using curl!"
system("curl", "-L", "-A", USER_AGENT, "-b", "tmp/cookie.txt", "-o", "tmp/youtube1.#{target_extension}", target)
puts "Start downloading using wget!"
system("wget", "-Ncq", "-e", "convert-links=off", "--load-cookies", "/dev/null", "--tries=200", "--timeout=20", "--no-check-certificate", "-O", "tmp/youtube2.#{target_extension}", target);
