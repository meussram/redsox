require 'resque'
require File.expand_path('../../lib/audio_file_parser', __FILE__)

# Array of audio files.
# Uploaded files, or files read from whatever resource are enqueued as shown below
files = ['102067__lg__waterfall-saas-fee-catchment-south-big-01-100609.wav', '3373__suonho__cartoonist_03_micious_suonho_.wav']

files.each do |file|
	
  Resque.enqueue(AudioFileParser, file)
  
end