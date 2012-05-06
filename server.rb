require 'sinatra'
require 'redis'
require 'YAML'
require "#{File.dirname(__FILE__)}/wrappers/redis_instance"

configure { set :server, :puma}
set :port, 9118

redis = Redis.new(RedisInstance.config)


get '/:id/plots' do
	audio_json = redis.hget("audio_files:#{params[:id]}", "json_plots")
end


get '/:id/timestamps' do 
	timestamps = redis.hget("audio_files:#{params[:id]}", "timestamps")
end


get '/:id/metadata' do
  meta={}
  
  keys = redis.hkeys("audio_files:#{params[:id]}")
  keys.each do |k|
    unless k == "json_plots" or k == "timestamps"
      meta[k] = redis.hget("audio_files:#{params[:id]}", "#{k}")
    end
  end
  meta.inspect
end