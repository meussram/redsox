require 'open3'
require 'yaml'

class Sox
  
  attr_accessor :install_dir
  
  
  def initialize
    
    configuration_root_dir = File.join(File.dirname(__FILE__),"..","conf")
    sox_config_file = YAML::load_file("#{configuration_root_dir}/sox.yml")
    @install_dir = sox_config_file["install_dir"]
    
  end
  
  
  def exec_cmd(cmd, param_in, param_out=nil, switches={})
    
    str = "#{@install_dir}/#{cmd} #{param_in} "
    
    switches.each do |k, v|
      str += "-#{k} #{v} "
    end
    
    str += "#{param_out}" 
    Open3.popen3("#{str}")
    
  end
  
end