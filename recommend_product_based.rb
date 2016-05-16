module Recommendation
  module RecommendMemory
    # Product-Based Memory Collaborative Filtering Method Implementation
    # Use set_data method to initialize object with users and products
    # recommendations_for method for getting recommended products for active user
    # find_top_similar_products method for finding most similar products to active product
    # Read comments in class to get a better insight on inner helper methods
    class RecommendProductBased < Recommendation::RecommendBase
      attr_accessor :users, :products, :default_recommendation_count, :default_similar_objects_count
      
      # Currently 2 methods are supported, Euclidean and Pearson Methods are
      # used to find similarities between products
      SIMILARITY_METHOD = 'euclidean' # euclidean OR pearson 
      MIN_SIMILARITY = 0.00001
      
      # Save computed data to a file to use faster in future
      SAVE_COMPUTED_PRODUCT_BASED_DATA = true
      PRODUCT_BASED_COMPUTED_DATA_FILE = File.dirname(__FILE__) + '/data/product_based_memory_data.dat'
      
      def initialize
        @file_path = PRODUCT_BASED_COMPUTED_DATA_FILE
        @save_data_to_file = SAVE_COMPUTED_PRODUCT_BASED_DATA
      end
      
      def set_data(users, products)
        @users, @products = users, products
      end
      
      # Find recommendations for the active user
      def recommendations_for(obj)
        recommend_by_product_based obj
      end
      
      # Calculates similarity points for the active product,
      # and returns top similar products array
      def find_top_similar_products(active_obj, top = nil)
        return unless active_obj
        
        similarities = []
        # an optimisation tweak, pre-fetch all users with the active product
        list = users_have_same_product active_obj
        @products.each_value do |obj|
          next if obj.id == active_obj.id # Skip the same object
          sim = similarity_for_products active_obj, obj, list
          next if sim < MIN_SIMILARITY
          similarities << { :id => obj.id, :similarity => sim }
        end
        similarities.sort{ |x, y| y[:similarity] <=> x[:similarity] }.first(top || similarities.size)
      end
      
      private
      
      # Used to calculate recommendation by Product-based CF method.
      # Takes all product that user rated, fetches all similar products for each user product
      # Adds to a weighted matrix, if the user has not already rated that product
      # Calculates the weighted value for each movie, return top movies
      def recommend_by_product_based(user, top = @default_recommendation_count)
        return unless @similarity_matrix
        
        weighted_similar_products = Hash.new(0.0)
        similarity_sum_per_product = Hash.new(0.0)
            
        user.list.products.each_value do |user_product|
          product = @products[user_product.id]
          
          sim_objs = @similarity_matrix[product.id]
          sim_objs.each do |obj|
            next if user.has_product? obj[:id]
            weighted_similar_products[obj[:id]] += user_product.rating * obj[:similarity].abs
            similarity_sum_per_product[obj[:id]] += obj[:similarity].abs
          end
        end
        
        recommendations = weighted_similar_products.collect do |k, v|
          next if v == 0.0 or similarity_sum_per_product[k] == 0.0
          { :id => k, :est => (v / similarity_sum_per_product[k]) }
        end
        recommendations.compact.sort{ |x, y| y[:est] <=> x[:est] }.first(top || recommendations.size)
      end
      
      # Predicts rating for an product for the active user
      # Calculates weighted rating sum of similar products
      def rating_for(active_user, product)
        return unless @similarity_matrix
        
        weighted_similar_products = similarity_sum = 0

        sim_objs = @similarity_matrix[product.id]
        sim_objs.each do |obj|
          active_user_rating = active_user.rating_for obj[:id]
          next unless active_user_rating
          weighted_similar_products += active_user_rating * obj[:similarity].abs
          similarity_sum += obj[:similarity].abs
        end
        
        return nil if weighted_similar_products == 0 or similarity_sum == 0
        
        rating = weighted_similar_products / similarity_sum
        rating = 5 if rating > 5
        rating = 1 if rating < 1
        rating
      end
      
      ### PRODUCTS BASED COLLABORATIVE FILTERING HELPER METHODS ###
      
      # Creates a matrix that stores each product's similar products.
      # This will extract information about the app's dataset, 
      # and we can use this as a model to make future predictions.
      # Takes Around 100 secs for 100K products, and around 4500 secs for 1M products
      def recompute_similarity_matrix
        start_time = Time.now
        puts "Creation of similarity matrix for products started at: #{start_time}."
        @similarity_matrix = {}
        @products.each_value do |product|
          puts "Started creating similar products for:#{product}"
          @similarity_matrix[product.id] = find_top_similar_products product, @default_similar_objects_count
        end
        
        puts "Creation of similarity matrix for products lasted: #{Time.now - start_time} seconds."
      end
      
      # Calls specified method to find similarity between two products
      # Uses passed list if any (used to gain perf. a little bit)
      def similarity_for_products(product1, product2, list = nil)
        # cache disabled
        # cached_sim = get_cached_similarity_for product1, product2
        # return cached_sim if cached_sim
        sim = 0.0
        case SIMILARITY_METHOD
          when 'euclidean'
            sim = similarity_by_euclidean_for_products product1, product2, list
          when 'pearson'
            sim = similarity_by_pearson_for_products product1, product2, list
          when 'jaccard'
            sim = similarity_by_jaccard_for_products product1, product2, list
        end
        sim.round(5)
        #set_similarity_cache_for product1, product2, sim
      end
      
      # Returns cached similarity for products
      def get_cached_similarity_for(product1, product2)
        @cached_similarities["#{product1}_#{product2}"] || @cached_similarities["#{product2}_#{product1}"]
      end
      
      # Sets similarity cache for 2 products
      def set_similarity_cache_for(product1, product2, sim)
        @cached_similarities["#{product1}_#{product2}"] = sim
      end
      
      # Find similarity value for 2 products.
      # First, finds common users who rated same products, then calculates 
      # the similarity by Euclidean
      def similarity_by_euclidean_for_products(product1, product2, list)
        common_users = find_common_users(product1, product2, list)
        
        result = 0.0
        return result if common_users.size < 1
        
        common_users.each do |u|
          result += (u.rating_for(product1.id) - u.rating_for(product2.id))**2
        end
        result = 1 / (1 + result)
        # result = 1 / (1 + Math.sqrt(result)) TODO: make tests to see the difference
      end
      
      # Find similarity value for 2 products.
      # First, finds common users who rated same products, then calculates 
      # the similarity by Pearson Correlation
      # Pearson Correlation will be between [-1, 1]
      def similarity_by_pearson_for_products(product1, product2, list)
        common_users = find_common_users(product1, product2, list)
        size = common_users.size
        
        return 0 if size < 1
        
        i1_sum_ratings = i2_sum_ratings = i1_sum_sq_ratings = i2_sum_sq_ratings = sum_of_products = 0.0
        common_users.each do |user|
          i1_rating = user.rating_for product1.id
          i2_rating = user.rating_for product2.id
          
          # Sum of all ratings by users
          i1_sum_ratings += i1_rating
          i2_sum_ratings += i2_rating
          
          # Sum of all squared ratings by users
          i1_sum_sq_ratings += i1_rating**2
          i2_sum_sq_ratings += i2_rating**2
          
          # Sum of product of the ratings that given to the same product
          sum_of_products += i1_rating * i2_rating
        end
    
        # Long lines of calculations, see http://davidmlane.com/hyperstat/A56626.html for formula.
        numerator = sum_of_products - ((i1_sum_ratings * i2_sum_ratings) / size)
        denominator = Math.sqrt((i1_sum_sq_ratings - (i1_sum_ratings**2) / size) * (i2_sum_sq_ratings - (i2_sum_ratings**2) / size))
        
        result = denominator == 0 ? 0 : (numerator / denominator)
        
        result = -1.0 if result < -1
        result = 1.0 if result > 1
        result
      end
      
      # Returns a list of users who rated a specified product
      def users_have_same_product(product)
        # TODO: .collect is slow? (for 100K dataset around 60secs.)
        #@users.collect { |k, u| u if u.has_product? product.id }.compact
        #@users.collect { |k, u| u if u.list.products[product.id] }.compact
        list = {}
        @users.each do |k, u|
          list[k] = u if u.has_product? product.id
        end
        list
      end
      
      # Finds common users for the products and returns an array contains user objects
      def find_common_users(product1, product2, list = @users)
        #list.collect { |u| u if u.has_product? product1.id and u.has_product? product2.id }.compact
        #list.collect { |u| u if u.list.products[product1.id] and u.list.products[product2.id] }.compact
        common = []
        list.each_value do |u|
          common << u if u.has_product? product1.id and u.has_product? product2.id
        end
        common
      end
      ### / PRODUCT BASED COLLABORATIVE FILTERING HELPER METHODS ###
    end
  end
end
