module Recommendation  
  module RecommendModel  
    class RecommendSVDIncremental < Recommendation::RecommendBase
      attr_accessor :users, :products
      
      FEATURE_INIT_VALUE    = 0.1
      FEATURE_NUM           = 10
      MIN_EPOCH_NUM         = 50
      MAX_EPOCH_NUM         = 100
      MIN_IMPROVEMENT       = 0.0001
      LEARNING_RATE         = 0.001
      K_VALUE               = 0.015
      
      def set_data(users, products)
        @users, @products, @ratings_cache = users, products, Hash.new(0.0)
        
        init_features
        calculate_features
      end
        
      def predict_rating_for(active_user, product)
        rating_for active_user, product
      end
      
      private
      
      def rating_for(user, product)
        rating = 1
        
        (1..FEATURE_NUM).each do |feat_ind|
          rating += @product_features[feat_ind][product.id] * @user_features[feat_ind][user.id]
          rating = 5 if rating > 5
          rating = 1 if rating < 1
        end
        rating
      end
      
      def calculate_features
        last_rmse = rmse = 2.0
        
        (1..FEATURE_NUM).each do |feat_ind|
          puts "Feature Calculation:#{feat_ind}"
          
          epoch_ind = 0
          while epoch_ind < MIN_EPOCH_NUM or rmse <= last_rmse - MIN_IMPROVEMENT
            last_rmse = rmse
            sq_error = 0
            
            rating_count = error = 0
            # Loop every rating
            @users.each_value do |user|
              user.list.products.each_value do |user_product|
                key = "#{user.id}_#{user_product.id}"          
                estimated_rating = estimate_rating(user.id, user_product.id, feat_ind, @ratings_cache[key], true)
                error = user_product.rating.to_f - estimated_rating
                sq_error += error**2
                
                uv = @user_features[feat_ind][user.id]
                iv = @product_features[feat_ind][user_product.id]
                
                @user_features[feat_ind][user.id] += LEARNING_RATE * (error * iv - (K_VALUE * uv))
                @product_features[feat_ind][user_product.id] += LEARNING_RATE * (error * uv - (K_VALUE * iv))
                
                rating_count += 1
              end
            end
            
            epoch_ind += 1
            rmse = Math.sqrt(sq_error / rating_count)
            break if epoch_ind > MAX_EPOCH_NUM
          end
          
          @users.each_value do |user|
            user.list.products.each_value do |user_product|
              key = "#{user.id}_#{user_product.id}"
              @ratings_cache[key] = estimate_rating(user.id, user_product.id, feat_ind, @ratings_cache[key])
            end
          end
        end
      end
      
      def estimate_rating(user_id, product_id, feat_ind, cache_val, b_trailing = false)
        rating = (cache_val != 0) ? cache_val : 1.0
        rating += @product_features[feat_ind][product_id] * @user_features[feat_ind][user_id]

        rating += (FEATURE_NUM - feat_ind - 1) * (FEATURE_INIT_VALUE**2)  if b_trailing
                
        rating = 5 if rating > 5
        rating = 1 if rating < 1
        
        rating
      end
      
      def init_features
        @product_size, @user_size = @products.size, @users.size
        @product_features, @user_features = {}, {}
        
        (1..FEATURE_NUM).each do |ind|
          @product_features[ind], @user_features[ind] = {}, {}
          
          @products.each { |k, _| @product_features[ind][k] = FEATURE_INIT_VALUE }
          @users.each { |k, _| @user_features[ind][k] = FEATURE_INIT_VALUE }
        end
      end
    end
  end
end
