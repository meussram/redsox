require 'resque'
require 'logger'

require "#{File.dirname(__FILE__)}/../wrappers/resque_error"
require "#{File.dirname(__FILE__)}/../wrappers/standard_streams"
require "#{File.dirname(__FILE__)}/../wrappers/redis_instance"
require "#{File.dirname(__FILE__)}/../wrappers/sox"
require "#{File.dirname(__FILE__)}/../extensions/proc"
require "#{File.dirname(__FILE__)}/audio_plots"


class AudioFileParser
  
  attr_accessor :filename, :audio_files_dir, :dat_files_dir, :number_of_samples
  @queue = 'audio_file_parsing'
  
  
  def initialize(filename)

    @log = Logger.new("#{File.dirname(__FILE__)}/../log/main.log")
    @log.level = Logger::DEBUG
    
    configuration_root_dir = File.join(File.dirname(__FILE__),"..","conf")
    resources_config_file = YAML::load_file("#{configuration_root_dir}/resources.yml")    
    @audio_files_dir = "#{File.join(File.dirname(__FILE__),"..","#{resources_config_file["audio_files"]}")}"
    @dat_files_dir =  "#{File.join(File.dirname(__FILE__),"..","#{resources_config_file["audio_dat_files"]}")}"

    @filename = filename
    
  end
  
  
  def get_audio_file_meta_data
    
    begin
      
      sox = Sox.new
      stdin, stdout, stderr, wait_thr = sox.exec_cmd("soxi", "#{audio_files_dir}/#{filename}")
      
    rescue Exception => msg
      @log.debug("#{Time.now}: An error occured:\n #{msg}\n")
    end
    
    err = stderr.read

    if err.length != 0
      
      ResqueError.new(stderr.read, @queue, self)
      StandardStreams.close(stderr, stdin, stdout)    
      return false
    
    else
      
      begin
        
        metadata = {} 
        stdout.readlines.each do |l|
        
          key = l.split(':')[0].strip
      
          unless key == ""          
            if key == "Duration"                      
              metadata["duration"] = l.split(/Duration\s+:/)[1].split('=')[0].strip
              metadata["number_of_samples"] = l.split('=')[1].split('samples')[0].strip                        
              @number_of_samples = metadata["number_of_samples"].to_i
            elsif key == "Input File"                         
              metadata["filename"] = l.split(':')[1].gsub("'", "").split('/').last.strip                  
            else            
              metadata["#{key.strip.gsub(" ", "_").downcase}"] = l.split(':')[1].strip                 
            end           
          end
          
        end
        
        StandardStreams.close(stderr, stdin, stdout)
      
      rescue Exception => msg
        @log.debug("#{Time.now}: An error occured:\n #{msg}\n")
      end
      
    end
    return metadata
      
  end
  
  
  def parse_audio_file(&block)
    
    output_sample_rate = set_output_sample_rate(@number_of_samples)
    
    begin
      
      sox = Sox.new
      switches = {"r" => output_sample_rate, "G" => ""}
      param_in = "#{audio_files_dir}/#{filename}"
      param_out = "#{dat_files_dir}/#{filename}.dat"
      
      stdin, stdout, stderr, wait_thr = sox.exec_cmd("sox", param_in, param_out, switches) 
         
      err = stderr.read
      err.length == 0 ? block.callback(:success) : block.callback(:failure, err)
      
      StandardStreams.close(stderr, stdin, stdout)
      
    rescue Exception => msg
      @log.debug("#{Time.now}: An error occured:\n #{msg}\n")
    end
    
  end
  
  # This method works but is more of a place holder. Need to add intelligence.
  def set_output_sample_rate(num_samples)
    
    begin
      
      if num_samples <= 44100
        output_sample_rate = num_samples
      elsif num_samples > 44100 and num_samples <= 600000
        output_sample_rate = 44100
      else
        output_sample_rate = 4000
      end 
      
      @log.info("#{Time.now}: Output Sample Rate: #{output_sample_rate}\n")
      return output_sample_rate
      
    rescue Exception => msg
      @log.debug("#{Time.now}: An error occured:\n #{msg}\n")
    end
    
  end
  
  
  def self.perform(filename)
    
    # Repetitive but we're in a class method so log needs to be declared here too
    log = Logger.new("#{File.dirname(__FILE__)}/../log/main.log")
    log.level = Logger::DEBUG
    redis = Redis.new(RedisInstance.config)
    
    parser = self.new(filename)
        
    # Getting the file's metadata
    log.info("#{Time.now}: Getting metadata for: #{filename}")  
    metadata = parser.get_audio_file_meta_data   
    log.info("#{Time.now}: metadata:\n#{metadata.inspect}")
    
    unless metadata == false
      # Increment ID in Redis for key "audio_files"
      id  = redis.incr "audio_files"
      
      # Parse metadata and store in Redis
      metadata.each do |k, v|
        redis.hset "audio_files:#{id}", k, v
      end
    end
    
    parser.parse_audio_file do |on|
            
      on.success do
        
        log.info("#{Time.now}: successfully parsed - #{filename}")
                   
        # Enqueue job AudioPlots in QUEUE 'audio_json_writing'
        Resque.enqueue(AudioPlots, filename, id, parser.dat_files_dir)

      end
      
      on.failure do |error|
               
        log.info("#{Time.now}: parsing failed - #{filename}")
        ResqueError.new(error, @queue, self)
             
      end
      
    end
    
  end
  
end