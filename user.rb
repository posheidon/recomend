module Recommendation
  # Stores user id, name attributes and an product_list object that holds all products user rated.
  class User
    attr_accessor :list
    attr_reader :id, :name
    
    # Initializes a new user with id, name and list of products
    def initialize(id, name, list = {})
      @id, @name = id, name
      @list = Recommendation::ProductList.new(list)
    end
    
    # Returns the product if user has rated that product
    def has_product?(id)
      @list.has_product? id
    end
    
    # Returns the rating of the product if user rated
    def rating_for(id)
      product = @list.find id
      product.rating if product
    end
    
    def to_s
      "User(#{@id}): #{@name}"
    end
  end
end
