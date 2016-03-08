# == Schema Information
#
# Table name: categories
#
#  id               :integer          not null, primary key
#  name             :string(255)      not null
#  title            :string(255)
#  description      :text(65535)
#  parent_id        :integer
#  status           :integer          default(1)
#  url              :string(255)
#  meta_title       :string(255)
#  meta_description :text(65535)
#  meta_keywords    :text(65535)
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#

class Category < ActiveRecord::Base
end
