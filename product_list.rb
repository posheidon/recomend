module Recommendation
  # Stores UserProduct objects
  class ProductList
    attr_accessor :products
    
    def initialize(list)
      @products = list || {}
    end
    
    # Adds a new product to the list
    def add(product)
      @products[product.id] = product
    end
    
    # Returns an product from the list by id
    def find(id)
      @products[id]
    end
    
    # Checks if product is in the list
    def has_product?(id)
      @products[id] != nil
    end
  
    def to_s
      "ProductList: #{@products.join(', ')}"
    end
  end
end
