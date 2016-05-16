module Recommendation
  # Stores id and name attributes for product
  class Product
    attr_reader :id, :name
    
    def initialize(id, name)
      @id, @name = id, name
    end
    
    def to_s
      "#{@id}-#{@name}"
    end
  end
end
