#! /usr/bin/env ruby

$LOAD_PATH << './lib'

require 'optparse'
require 'downloader'

def parse_turntable(songs=$stdin.readlines)
	puts "Parsing Turntable.FM input..." if options[:verbose]
	songs.map do |song|
		song.sub!(/\s*\(\d+\)$/, '')											# Remove popularity index
		parse_input_string(song).sub!('_by_', '_')				# Remove song/artist delimiter
	end
end

options = {}

OptionParser.new do |opts|
	opts.banner = "Usage: download.rb [options] song1 song2 ..."
	
	options[:play] = false
	opts.on( '-p', '--play', 'Play song after downloading' ) do
		options[:play] = true
	end
	
	options[:quality] = 0
	opts.on( '-q', '--quality [KBPS]', Integer, 'Minimum quality mp3 in KBPS' ) do |kbps|
		options[:quality] = kbps || 160
	end
	
	options[:verbose] = false
	opts.on( '-v', '--verbose', 'Output more information' ) do
		options[:verbose] = true
	end
	
	options[:log] = "log.txt"
	opts.on( '-l', '--logfile FILE', 'Write log to FILE' ) do |file|
		options[:log] = file
	end
	
	options[:path] = "~/Downloads"
	opts.on( '-d', '--path PATH', 'Save mp3 file to PATH' ) do |path|
		options[:path] = path
	end
	
	opts.on( '-h', '--help', 'Display help' ) do
		puts opts
		exit
	end
end.parse!

raise(ArgumentError, "No search terms specified") if ARGV.empty?
puts "Verbose mode enabled" if options[:verbose]
puts "Logging output to #{options[:log]}" if options[:verbose]
puts "Minimum quality: #{options[:quality]}kbps" if options[:quality] > 0
puts "Search result for \"#{ARGV.last}\" will begin playing after download is complete" if options[:play]

downloader = Downloader.new(ARGV, options)
downloader.match_songs
last_song = downloader.download_songs

if options[:play]
	program = case `printf $(command -v afplay >/dev/null 2>&1)$?`
						when "0"; "afplay"
						else "open"
						end
	if program == 'afplay'
		puts "Press Control-C to stop playback"
		begin
			`#{program} "#{last_song.mp3_file}"`
		rescue Interrupt
			puts
			exit(0)
		end
	end
end




# TODO
# - add support for download progress viewer
# - add threads for concurrent downloads?
# - add songs to iTunes playlist
# - add dilandau.eu support
# - streaming support
# - switch up search term order
# - check validity of mp3, retry if invalid
# - test matches for equality (by URI, or better yet by accurate file size?)
# - improve match.fit calculation (look for keywords live, cover, remix, etc; add the)
# bug - @matches don't seem to be sorting by quality when quality is nil
# bug - need to error out if no matches found
