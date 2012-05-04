class StandardStreams < IO
  
  def self.close(*streams)
    streams.each {|s| s.close if s.class == IO}     
  end
    
end