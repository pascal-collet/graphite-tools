#!/usr/bin/ruby
#
# Extract graphite metric for a given path. 
#
# -------------------------------------------------------------------------------------------------
#
# Getting raw numerical data out of Graphite (from http://graphite.wikidot.com/url-api-reference)
#
# Graphite can return numerical data in a CSV format by simply adding a "rawData=true" url parameter 
# to any graphite image url. The output format is as follows:
#
# target1, startTime, endTime, step | value1, value2, ..., valueN
# target2, startTime, endTime, step | value1, value2, ..., valueN
# ...
# Each line corresponds to a graph element. Everything before the "|" on a given line is header 
# information, everything after is numerical values. The header describes the name of the target, 
# the start and end times (in unix epoch time) of the retrieved interval, and the step is the number
# of seconds between datapoints. So the timestamp of value1 is startTime, the timestamp of value2 is 
# (startTime+step), value3 is (startTime+step+step), etc…
#
# Note that non-existent or null values in a series are represented by the string "None".
#
# -------------------------------------------------------------------------------------------------
#
# Author: Pascal Collet (c) 2011
#
# -------------------------------------------------------------------------------------------------
#
# Usage: 
#    $ fetchGraphite <start datetime> <end datetime>
#
# -------------------------------------------------------------------------------------------------
# Requisite:
#    - you will need to install R and rsruby in order to plot and get statistical information.
#    - to install rsruby on MacOSX
#           $  gem install rsruby -- --with-R-dir=/Library/Frameworks/R.framework/Resources
#    - to install R see http://cran.r-project.org/bin/macosx/
#
# -------------------------------------------------------------------------------------------------

require 'cgi'
require 'open-uri'
require 'rubygems'
require 'rsruby'

PROD_PREFIX = "http://graphite.prod.o.com/render/?rawData=true"
STAG_PREFIX = "http://graphite.stag.o.com/render/?rawData=true"

def construct_url(prefix, target, start, finish)
  url = "#{prefix}&target=#{target}&from=#{start}&until=#{finish}"
end

def retrieve_prod_data(path, start, finish)
  url = construct_url(PROD_PREFIX, path, start, finish)
  data = open(url) {|f| f.read }
end

def construct_date(date_str)
  Time.parse(date_str).strftime("%H:%M_%G%m%d").sub(":", "%3A")
end

def extract_dataset(data)
  # remove the final return carriage
  data = data.chomp()
  # remove header (separated with '|')
  data = data.slice(data.index("|")+1..-1)
  # create an array of float from the "," separated strings
  data_set = data.split(",").map { |s| s.to_f }
end

def extract_header(data)
  all_header = data.slice(0 .. data.index("|")-1)
  matching_headers = /(.*?),(\d+),(\d+),(\d+)/.match(all_header)
  raise "Cannot parse #{all_header}" if matching_headers == nil
  p matching_headers
  serie_name = matching_headers[1]
  start_time = matching_headers[2].to_i
  end_time = matching_headers[3].to_i
  step = matching_headers[4].to_i
  [serie_name, start_time, end_time, step]
end

def print_stats(data)
  r = RSRuby.instance
  stats = r.summary(data)
  puts "Average is #{stats['Median']} with min=#{stats['Min.']} / max = #{stats['Max.']}"
end

def create_labels_dictionary(starttime, endtime, step)
  labels = {}
  counter = 0 ## ugly!!
  Range.new(starttime, endtime).step(step) { |time_label|  
    labels[counter.to_i] = Time.at(time_label).strftime("%Y-%m-%d %H:%M")
    counter += 1
  }
  labels
end

def create_labels(starttime, endtime, step)
  labels = []
  starttime.step(endtime-step, step) { |time_label| labels << Time.at(time_label).strftime("%Y-%m-%d %H:%M") }
  labels
end

# =================================================================================================

if ARGV.length != 2
  puts "Usage: fetchGraphite.rb <start datetime> <end datetime>"
  puts "  - The datetime should follow \"2011-08-30 13:34\" format"
  exit(0)
end

path = "timeShift(PRO2.streambase.omh.all.jiniIn.HotelBaseRateService.fetchBaseRates.avgLatency%2C%227d%22)"
puts "Fetching data from #{ARGV[0]} to #{ARGV[1]} for #{path}..."
raw_data = retrieve_prod_data(path, construct_date(ARGV[0]), construct_date(ARGV[1]))
dataset = extract_dataset(raw_data)
serie_name, starttime, endtime, step = extract_header(raw_data)
puts "Got #{dataset.length} #{serie_name} items starting from #{Time.at(starttime)} ending at #{Time.at(endtime)} every #{step} seconds"
plot(path, dataset, create_labels(starttime, endtime, step))
print_stats dataset