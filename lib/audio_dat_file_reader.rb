class AudioDatFileReader
  
  attr_accessor :dat_file_name
  
  def initialize (filename)
   
    @dat_file_name = filename
    
  end
  
  
  def read_dat_file
    
    timestamps = []
    vals = []
    j = 0
    
    File.open(File.dirname(__FILE__)+"/../audio_dat/#{dat_file_name}").each_with_index { |line, i|
      
      tmp = line.split(' ')
      next if (i == 0 or i == 1)
      
      timestamps << tmp[0].to_f
      
      ch1 = tmp[1].to_f * 100000.to_f
      ch2 = tmp[2].to_f * 100000.to_f

      val = ch1 + ch2
      vals << ch1 +ch2 

    }
    return vals, timestamps

  end
  
end