#!/usr/bin/ruby
#
# Extract graphite metric for a given path
#
# Author: Pascal Collet
#

require 'cgi'
require 'open-uri'

PROD_PREFIX = "http://graphite.prod.o.com/render/?rawData=true"
STAG_PREFIX = "http://graphite.stag.o.com/render/?rawData=true"

def construct_url(prefix, target, start, finish)
  url = "#{prefix}&target=#{target}&from=#{start}&until=#{finish}"
end

def retrieve_prod_data(path, start, finish)
  url = construct_url(PROD_PREFIX, path, start, finish)
#  puts url
  data = open(url) {|f| f.read }
#  puts data
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


path = "PRO2.streambase.omh.all.jiniIn.HotelBaseRateService.fetchBaseRates.avgLatency"
data = retrieve_prod_data(path, construct_date(ARGV[0]), construct_date(ARGV[1]))
#puts data

data = extract_dataset(data)
puts data