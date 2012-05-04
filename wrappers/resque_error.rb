class ResqueError
  
  def initialize(message, queue, worker)
    
    exception = StandardError.new(message)
    Resque::Failure.create(:exception => exception, :queue => queue, :worker => worker)
    
  end
  
  
end