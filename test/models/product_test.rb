# == Schema Information
#
# Table name: products
#
#  id               :integer          not null, primary key
#  name             :string(255)
#  description      :text(65535)
#  url              :string(100)
#  meta_title       :string(255)
#  meta_description :text(65535)
#  meta_keywords    :text(65535)
#  company_id       :integer
#  price            :float(24)
#  mrp              :float(24)
#  weight           :float(24)
#  rank             :integer
#  status           :integer          default(0)
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#

require 'test_helper'

class ProductTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
