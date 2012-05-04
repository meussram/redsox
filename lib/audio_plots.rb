require "#{File.dirname(__FILE__)}/audio_dat_file_reader"
require "#{File.dirname(__FILE__)}/../wrappers/redis_instance"


class AudioPlots
  
  attr_accessor :dat_file_name, :audio_file_name
  @queue = 'audio_plot_points_to_redis'
  
  def initialize(filename)
    
    @log = Logger.new("#{File.dirname(__FILE__)}/../log/main.log")
    @log.level = Logger::DEBUG
    
    @audio_file_name = filename
    @dat_file_name =  "#{filename}.dat"
    
     # This is arbitrary, based on the wav project. Needs to be dynamic based on number of samples from original file and from expected user experience
    @number_of_points = 20000
      
  end


  def parse_dat_file
    
    indexes = []
    avg = []
    graph_plots = []
    compacted_timestamps = []
    x = 0

    dat_file = AudioDatFileReader.new(dat_file_name)
    
    data_points, timestamps = dat_file.read_dat_file
    
    factor = (data_points.length / @number_of_points).round
    
    data_points.each_index do |i|
      if i % factor == 0
        indexes << i
      end
    end
    
    indexes.each_index do |k|
      unless k == 0
        temp = 0
        for j in indexes[k - 1] .. indexes[k] do
          temp = data_points[j] + temp
        end
        compacted_timestamps << timestamps[j]
        avg << (temp / factor)
      end
    end
      
    avg.each_index do |i|
      graph_plots << [x, avg[i].to_i]
      x+=1
    end

    return compacted_timestamps, graph_plots    

  end
  
  
  def write_plots_to_redis(file_name, file_id, &block)
    
    begin      
      redis = Redis.new(RedisInstance.config)
      
      timestamps, graph_plots = parse_dat_file
      graph_plots_hash = {"data" => graph_plots}
      
      @log.info("#{Time.now}: Setting timestamps in REDIS - #{file_name}")
      redis.hset "audio_files:#{file_id}", "timestamps", timestamps
      @log.info("#{Time.now}: Setting json plots in REDIS - #{file_name}")
      redis.hset "audio_files:#{file_id}", "json_plots", graph_plots_hash
      
      block.callback(:success)
      
    rescue Exception => msg      
      @log.debug("An error occured: #{msg}")
      block.callback(:failure, msg)       
    end    
    
  end
  
  
  def self.perform(file_name, file_id, dat_files_dir)
    
    # Repetitive but we're in a class method so log needs to be declared here too
    log = Logger.new("#{File.dirname(__FILE__)}/../log/main.log")
    log.level = Logger::DEBUG
    
    redis = Redis.new(RedisInstance.config)
    plots = self.new(file_name)


    plots.write_plots_to_redis(file_name, file_id) do |on|
      
      on.success do # Remove .dat file from file system
        begin
          log.info("#{Time.now}: Removing .dat file - #{plots.dat_file_name}\n")
          exec("rm #{dat_files_dir}/#{plots.dat_file_name}")
        rescue Exception => msg
          log.debug("An error occured: #{msg}")
        end
      end
      
      on.failure do |error|
        log.info("#{Time.now}: writing plots to Redis failed: #{error} - #{filename}")
        ResqueError.new(error, @queue, self)
      end
      
    end
    
  end

end