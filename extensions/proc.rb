class Proc
  
  # Creates dynamic callbacks. Courtesy of Matt Sears. 
  # http://www.mattsears.com/articles/2011/11/27/ruby-blocks-as-dynamic-callbacks
  # http://techscursion.com/2011/11/turning-callbacks-inside-out
  def callback(callable, *args)
    self === Class.new do
    method_name = callable.to_sym
    define_method(method_name) { |&block| block.nil? ? true : block.call(*args) }
    define_method("#{method_name}?") { true }
    def method_missing(method_name, *args, &block) false; end
    end.new
  end
  
end