# A simple class to test CF algorithms using MovieLens 100K or 1M sample datasets
require './../lib/recommend_factory'

class RecommendTest
  # MEMORY_BASED or MODEL_BASED
  CF_METHOD_TYPE = Recommendation::MODEL_BASED
  # USER_BASED or PRODUCT_BASED or SVD_PRODUCT_BASED or SVD_USER_BASED or SVD_INCREMENTAL
  CF_ALGORITHM   = Recommendation::SVD_INCREMENTAL
  
  REGENERATE_PRODUCT_BASED_DATA = true
  REGENERATE_SVD_DATA        = true
  
  # 1M => data/ml-1m/   // 100K => data/ml-100k/
  ML_BASE_FOLDER         = "../lib/data/ml-100k/"
  # 1M => users.dat     // 100K => u.user
  ML_USERS_FILE          = "#{ML_BASE_FOLDER}u.user"
  # 1M => movies.dat    // 100K => u.product
  ML_MOVIES_FILE         = "#{ML_BASE_FOLDER}u.product"
  # 1M => ratings.dat   // 100K => u.data  // 100K TEST => ua.base
  ML_RATINGS_FILE        = "#{ML_BASE_FOLDER}ua.base"
  ML_TEST_COMPARE_FILE   = "#{ML_BASE_FOLDER}ua.test"
  # 1M => "::" // 100K => "|"
  # NOTE: for 100K MovieLens data, value separation characters are changed from space (' ') to "|" (u.data, ua.base, ua.test files)
  ML_PRODUCT_SEPARATOR      = "|"

  def initialize
    @products, @users, @ratings = {}, {}, {}
  end
    
  # Runs the test.
  # Gets a new instance of the specified CF implementation (by using Recommendation::Factory.get)
  # To re-generate the models, set above (REGENERATE_PRODUCT_BASED_DATA and REGENERATE_SVD_DATA) constants to true
  # Otherwise system will use pre-computed models by loading from file system
  def run
    start_time = Time.now
    puts "MovieLens data started loading at: #{start_time}."
    load_data_from_movielens
    load_data_end_time = Time.now 
    puts "MovieLens data loaded in #{load_data_end_time - start_time} seconds."
    puts '**************************************************'
    
    puts "Total Users  : #{@users.size}"
    puts "Total products  : #{@products.size}"
    puts "Total Ratings: #{@total_rating_count}"
    puts '**************************************************'

    puts "MovieLens recommendation started at: #{load_data_end_time} seconds."
    recsys = Recommendation::Factory.get CF_METHOD_TYPE, CF_ALGORITHM
    recsys.set_data @users, @products
    #recsys.default_similar_objects_count = 500
    
    if CF_ALGORITHM == Recommendation::PRODUCT_BASED
      recsys.precompute REGENERATE_PRODUCT_BASED_DATA
    elsif CF_ALGORITHM == Recommendation::SVD_USER_BASED or CF_ALGORITHM == Recommendation::SVD_PRODUCT_BASED
      recsys.precompute REGENERATE_SVD_DATA
    end

=begin
    puts "Top 2 users' recommendations ......"
    (1..2).each do |i|
      recs = recsys.recommendations_for @users[i]
      next unless recs
      print "Recommendations for #{@users[i].name} are: "
      recs.each { |r| puts "#{@products[r[:id]].name} - #{r[:est]}" }
      puts '*'*100
    end
=end
    
    recommendation_end_time = Time.now
    puts "MovieLens recommendation ended at: #{recommendation_end_time - load_data_end_time}."
    
    load_test_ratings
    puts "MovieLens test data comparison started at: #{recommendation_end_time} seconds."
    
    compare_movielens_test_results recsys
    
    puts "MovieLens test data comparison ended at: #{Time.now - recommendation_end_time} seconds."
  end
  
  private
  # Loads test ratings from ML_TEST_COMPARE_FILE to compare predictions and 
  # actual ratings for user-product-rating triples
  def load_test_ratings
    File.open(ML_TEST_COMPARE_FILE).each do |line|
      vals = line.split(ML_PRODUCT_SEPARATOR)
      user_id, product_id, rating = vals[0].to_i, vals[1].to_i, vals[2].to_i

      next if user_id == 0 or product_id == 0 or rating == 0
      
      user = @users[user_id]
      product = @products[product_id]
      next if user.nil? or product.nil?
      
      @ratings[user.id] ||= []
      @ratings[user.id] << { :product_id => product.id, :rating => rating }
    end
  end
  
  # Compare ML test results.
  # Used Root Mean Square Error (RMSE) to find the error on estimations
  def compare_movielens_test_results(recommend)
    sq_sum_of_diff, product_count = 0.0, 0
    
    rating_ind = 0
    @ratings.each do |k, v|
      rating_ind += 1

      v.each do |rating_pair|
        product_id = rating_pair[:product_id]
        rating = rating_pair[:rating]
        
        prediction = recommend.predict_rating_for @users[k], @products[product_id]
        next unless prediction
        
        product_count += 1
        sq_sum_of_diff += (prediction - rating)**2
        
        puts "#{@products[product_id]} Original:#{rating}. Estimated:#{prediction}"
      end
    end
    result = Math.sqrt(sq_sum_of_diff / product_count)
    puts "PRODUCT_COUNT: #{product_count}"
    puts "RESULT    : #{result}"
  end
  
  # Loads triples (user-product-rating) from files
  def load_data_from_movielens
    load_users_from_movielens
    load_movies_from_movielens    
    load_ratings_from_movielens
  end
  
  # Loads user file and creates objects to use
  def load_users_from_movielens
    File.open(ML_USERS_FILE).each do |line|
      id = line.split(ML_PRODUCT_SEPARATOR)[0].to_i
      @users[id] = Recommendation::User.new(id, "U-#{id}")
    end
  end
  
  # Loads movies (products) file and creates objects to use
  def load_movies_from_movielens
    File.open(ML_MOVIES_FILE, :encoding=>"ASCII-8BIT").each do |line|
      id = line.split(ML_PRODUCT_SEPARATOR)[0].to_i
      title = line.split(ML_PRODUCT_SEPARATOR)[1]
      @products[id] = Recommendation::Product.new(id, title)
    end
  end
  
  # Loads ratings file and creates objects to use
  def load_ratings_from_movielens
    @total_rating_count = 0
    File.open(ML_RATINGS_FILE).each do |line|
      user_id = line.split(ML_PRODUCT_SEPARATOR)[0].to_i
      product_id = line.split(ML_PRODUCT_SEPARATOR)[1].to_i
      rating = line.split(ML_PRODUCT_SEPARATOR)[2].to_i
      next if user_id == 0 or product_id == 0 or rating == 0
      
      user = @users[user_id]
      product = @products[product_id]
      next if user.nil? or product.nil?
      
      @total_rating_count += 1
      user.list.add Recommendation::UserProduct.new(product, rating)
    end
  end
  
  # Used to display a summary of users and their products.
  # Not suitable for large datasets, use this with small user/products lists
  def display(type = 'all')
    @users.each_value do |u|
      puts "#{u.name} products: "
      u.list.products.each_value do |user_product|
        puts "#{@products[user_product.id]}-#{user_product.rating}"
      end
      puts
    end
  end
end
