# Imports the required files
# Provides a getter method to return a new instance of CF Approach
# Existing implementations are listed below,
# Every new implementation has to be added here.
module Recommendation
  BASE_DIR = File.dirname(__FILE__) + '/'
  require "#{BASE_DIR}product"
  require "#{BASE_DIR}user_product"
  require "#{BASE_DIR}product_list"
  require "#{BASE_DIR}user"
  require 'linalg'
    
  require "#{BASE_DIR}recommend_base"
  require "#{BASE_DIR}recommend_product_based"
  require "#{BASE_DIR}recommend_user_based"
  require "#{BASE_DIR}recommend_svd_user_based"
  require "#{BASE_DIR}recommend_svd_product_based"
  require "#{BASE_DIR}recommend_svd_incremental"
  
  MEMORY_BASED    = 'memory_based'
  MODEL_BASED     = 'model_based'
  
  PRODUCT_BASED      = 'product_based'
  USER_BASED      = 'user_based'
  SVD_USER_BASED  = 'svd_user_based'
  SVD_PRODUCT_BASED  = 'svd_product_based'
  SVD_INCREMENTAL = 'svd_incremental'
  
  class Factory
    # Static method returns a new instance of CF Implementation
    def self.get(type, algo)
      if type == Recommendation::MEMORY_BASED
        if algo == Recommendation::PRODUCT_BASED
          Recommendation::RecommendMemory::RecommendProductBased.new
        elsif algo == Recommendation::USER_BASED
          Recommendation::RecommendMemory::RecommendUserBased.new
        end
      elsif type == Recommendation::MODEL_BASED
        if algo == Recommendation::SVD_PRODUCT_BASED
          Recommendation::RecommendModel::RecommendSVDProductBased.new
        elsif algo == Recommendation::SVD_USER_BASED
          Recommendation::RecommendModel::RecommendSVDUserBased.new
        elsif algo == Recommendation::SVD_INCREMENTAL
          Recommendation::RecommendModel::RecommendSVDIncremental.new
        end
      end
    end
  end
end
