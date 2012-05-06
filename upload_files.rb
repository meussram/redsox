require 'rubygems'
require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/base' 
require 'YAML'
require 'resque'
require File.expand_path('../lib/audio_file_parser', __FILE__)

class MyApp < Sinatra::Base
  
  configure { set :server, :puma }

	set :static, true
	set :public, File.dirname(__FILE__) + '/public'
	enable :sessions
	
	
  get '/' do
    erb :index
  end
  

  get '/upload' do
    erb :upload
  end
  

  post '/upload' do
    configuration_root_dir = File.join(File.dirname(__FILE__),"","conf")
    resources_config_file = YAML::load_file("#{configuration_root_dir}/resources.yml")
    @audio_files_dir = "#{File.join(File.dirname(__FILE__),"","#{resources_config_file["audio_files"]}")}"
 
    File.open("#{@audio_files_dir}/" + params['sound'][:filename], "w") do |f|
      f.write(params['sound'][:tempfile].read)
      Resque.enqueue(AudioFileParser, params['sound'][:filename])
    end
		
  end
  
  get '/wave/*' do
    erb :index
  end
  
end

MyApp.run!  #if $0 == __FILE__
