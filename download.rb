#! /usr/bin/env ruby

require 'nokogiri'
require 'open-uri'
require 'optparse'

def parse_input_string(string)
	str = string.gsub(/\W/, ' ')					# Remove non-word characters
	str.strip!														# Remove excess whitespace
	str.gsub!(/\s+/, '_')									# Delimit terms with underscore
end

def parse_turntable(songs=$stdin.readlines)
	puts "Parsing Turntable.FM input..." if $options[:verbose]
	songs.map do |song|
		song.sub!(/\s*\(\d+\)$/, '')											# Remove popularity index
		parse_input_string(song).sub!('_by_', '_')				# Remove song/artist delimiter
	end
end

def parse_mp3_skull(search_term)
	puts "Downloading search results for #{search_term}..." if $options[:verbose]
	uri = "http://mp3skull.com/mp3/#{search_term}.html"
	
	begin
		doc = Nokogiri::HTML(open(uri))
	rescue SocketError => error
		raise(error, "Check your internet connection")
	end
	
	puts "Parsing HTML..." if $options[:verbose]
	array = doc.css('div#song_html').map do |song_element|
		hash = {}
		hash[:name] = song_element.css('#right_song div b').first.content.encode('UTF-16', :invalid => :replace).encode('UTF-8').chomp(" mp3")
		hash[:uri] = URI.escape(song_element.css('#right_song a').first['href'])
		hash[:extra_words] = hash[:name].scan(/\b/).size/2 - search_term.split("_").count
		hash.merge(parse_left_content(song_element.css('div.left').first.content))
	end
	raise(ArgumentError, "No matches found for #{search_term}, bummer.") if array.empty?
	array.reject! { |hash| (hash[:quality] || 320) < $options[:quality] }
	array.sort_by { |hash| [hash[:extra_words], -(hash[:quality] || 0)] }
end

def parse_left_content(content)
	m = content.match(/(\d+)\s*kbps/)
	kbps = m && m[1].to_i
	m = content.match(/(?<hours>\d{1,2})?:?(?<minutes>\d{1,2}):(?<seconds>\d{2})/)
	seconds = m && m[:seconds].to_i + m[:minutes].to_i * 60 + m[:hours].to_i * 60 * 60
	m = content.match(/(?:\d:\d{2})?([\d\.]+) mb/)
	mb = m && m[1].to_f
	{:quality => kbps, :time => seconds, :size => mb}
end

def download(songs)
	song = songs.shift
	raise(ArgumentError, "No matches left to try") if song.nil?
	puts "Song match: #{song[:name]}\nURL: #{song[:uri]}\nQuality: #{song[:quality]}kbps\nTime: #{song[:time]} seconds\nSize: #{song[:size]} mb"
	mp3_file = File.expand_path(song[:name] << ".mp3", $options[:path])
	File.open(mp3_file, "wb") do |saved_file|
		puts "Downloading to #{mp3_file}..."
		open(song[:uri], 'rb') do |read_file|
			saved_file.write(read_file.read)
		end
	end
rescue => error
	puts error.message, "Trying next song match..."
	retry
else
	File.open($options[:log], "a") do |log|
		log.puts(Time.now, "URL: #{song[:uri]}", "File: #{mp3_file}")
	end
	mp3_file
end


$options = {}

optparse = OptionParser.new do |opts|
	opts.banner = "Usage: download.rb [options] song1 song2 ..."
	
	$options[:play] = false
	opts.on( '-p', '--play', 'Play song after downloading' ) do
		$options[:play] = true
	end
	
	$options[:quality] = 0
	opts.on( '-q', '--quality [KBPS]', Integer, 'Minimum quality mp3 in KBPS' ) do |kbps|
		$options[:quality] = kbps || 160
	end
	
	$options[:verbose] = false
	opts.on( '-v', '--verbose', 'Output more information' ) do
		$options[:verbose] = true
	end
	
	$options[:log] = "log.txt"
	opts.on( '-l', '--logfile FILE', 'Write log to FILE' ) do |file|
		$options[:log] = file
	end
	
	$options[:path] = "~/Downloads"
	opts.on( '-d', '--path PATH', 'Save mp3 file to PATH' ) do |path|
		$options[:path] = path
	end
	
	opts.on( '-h', '--help', 'Display help' ) do
		puts opts
		exit
	end
end


optparse.parse!

raise(ArgumentError, "No search terms specified") if ARGV.empty?
puts "Verbose mode enabled" if $options[:verbose]
puts "Logging output to #{$options[:log]}" if $options[:verbose]
puts "Minimum quality: #{$options[:quality]}kbps" if $options[:quality] > 0
puts "Search result for \"#{ARGV.last}\" will begin playing after download is complete" if $options[:play]


$file_name = ""
ARGV.each do |song|
	search_string = parse_input_string(song)
	search_results = parse_mp3_skull(search_string)
	$file_name = download(search_results)
end

if $options[:play]
	program = case `printf $(command -v afplay >/dev/null 2>&1)$?`
						when "0"; "afplay"
						else "open"
						end
	puts "Press Control-C to stop playback" if program == "afplay"
	begin
		`#{program} "#{$file_name}"`
	rescue Interrupt
		puts
		exit
	end
end




# TODO
# - add support for download progress viewer
# - restructure code, get rid of global variables
# - add threads for concurrent downloads?
# - add songs to iTunes playlist
# - add dilandau.eu support
# - streaming support
# - switch up search term order
# - check validity of mp3, retry if invalid
