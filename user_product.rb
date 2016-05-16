module Recommendation
  # A user-rating object that stores a rating user gave for a specific product
  class UserProduct
    attr_reader :id, :rating
    
    def initialize(product, rating)
      @id, @rating = product.id, rating
    end
    
    def to_s
      "UserProduct:#{@id},R:#{@rating}"
    end
  end
end
