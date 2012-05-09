class RedisInstance
  
  def self.config
    
    configuration_root_dir = File.join(File.dirname(__FILE__),"..","conf")
    redis_config_file = YAML::load_file("#{configuration_root_dir}/redis.yml")
    redis_config = {:host => redis_config_file["host"], :port => redis_config_file["port"]}
    
  end
  
end