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

class Product < ActiveRecord::Base
  #relations
  has_many :product_sizes
  has_many :product_categories
  has_many :child_categories, through: :product_categories, source: :category
  belongs_to :color
  belongs_to :designer
  belongs_to :model
  has_many :purchase_order_products
  has_many :filter_products
  has_many :filters, through: :filter_products
  has_many :images, as: :imageable
  has_many :frame_products
  has_many :collection_products
  has_many :collections, through: :collection_products
  #enums
  enum status: [:disabled, :enabled, :discontinued, :"comming soon" ]
  enum base_inventory: [:unlimited, :color, :inventory]

  validates_presence_of :name, :description, :url, :status, :price, :mrp, :weight, :base_inventory, :color_id, unless: lambda{ |product| product.no_validate }
  validates_presence_of :sizes, :child_category_ids, on: :create, unless: lambda { |product| product.no_validate }
  validates_uniqueness_of :url, unless: lambda { |product| product.no_validate }

  searchable  :auto_index => false do
    integer :id, :stored => true
    string :name, :stored => true
    text :name, :as => :name_text_search
    string :description, :stored => true
    string :product_description, :stored => true do
      product_description if child_categories.present?
    end
    string :model_description, :stored => true do
      model_description if child_categories.present?
    end
    integer :launched_timestamp, :stored => true do
      launched_at.present? ? launched_at.to_time.to_i : 0
    end
    integer :updated_timestamp, :stored => true do
      updated_at.present? ? updated_at.to_time.to_i : 0
    end
    string :tabular_description, :stored => true do
      tabular_description if child_categories.present?
    end
    string :fabric_detail, :stored => true
    string :fit_description, :stored => true
    string :delivery_and_return_policy, :stored => true
    string :url, :stored => true
    float :mrp, :stored => true
    float :price, :stored => true
    integer :rank, :stored => true
    integer :recommended_rank, :stored => true
    integer :category_rank, :stored => true do
      [(product_categories.first.try(:priority) || 0), recommended_rank].max
    end
    integer :weight, :stored => true
    integer :status, :stored => true do
      statuses[status]
    end
    text :product_sizes, :stored =>true do
      product_sizes.enabled.map { |product_size| [product_size.id,product_size.size_name, product_size.qty_avail].join('|') }
    end
    text :images, :stored =>true do
      images.order("priority asc").map { |image| [image.image_file_name,image.priority,image.sub_type].join('|') }
    end
    integer :child_category_ids , multiple: true, :stored =>true do
      child_categories.sort.map(&:id)
    end
    integer :child_category_status , multiple: true, :stored =>true do
      child_categories.sort.map { |category| Category.statuses[category.status] }
    end
    string :child_category_names , multiple: true, :stored =>true do
      child_categories.sort.map { |category| category.name }
    end
    text :child_category_names do
      child_categories.sort.map { |category| category.name }
    end
    string :child_category_urls , multiple: true, :stored =>true do
      child_categories.sort.map { |category| category.url }
    end
    integer :parent_category_ids , multiple: true, :stored =>true do
      child_categories.first.category.id if child_categories.present? and child_categories.first.category.present?
    end
    string :parent_category, :stored => true do
      child_categories.first.category.name if child_categories.present? and child_categories.first.category.present?
    end
    text :parent_category do
      child_categories.first.category.name if child_categories.present? and child_categories.first.category.present?
    end
    string :parent_category_url, :stored => true do
      child_categories.first.category.url if child_categories.present? and child_categories.first.category.present?
    end
    integer :parent_category_status, :stored => true do
      Category.statuses[child_categories.first.category.status] if child_categories.present? and child_categories.first.category.present?
    end
    integer :color_id, :stored => true
    string :color_name, :stored => true do
      color.name if color!=nil
    end
    text :filters, :stored =>true do
      filters.where("status=1").order("priority asc").map {
       |filter| [filter.name,filter.value].join('|')
     }
    end
    string :collection_urls , multiple: true, :stored =>true do
      collections.enabled.map { |collection| collection.url }
    end
    integer :collection_status , multiple: true, :stored =>true do
      collections.enabled.map { |collection| Collection.statuses[collection.status] }
    end
  end
  def recommended_rank
    (stock_factor || 0)*(sales_factor || 0)
  end
  def size_ids
    self.product_sizes.map{|product_size| product_size.size_id}
  end

  def image_upload(sub_category,image_file_name,action_type)
    # This function will take display image from display folder and original image from main folder
    # used by bulk change and bulk upload too !
    folder_path = APP_CONFIG["path_bulk#{action_type}"]
    folders_list = ["main","display"]
    product_id = self.id
    folders_list.each do |folder_name|
      image_path =  "#{folder_path}/#{sub_category}/#{folder_name}/#{image_file_name}_#{folder_name}.jpg"
      image_handler = File.open(image_path)
      if image_handler!= nil
        sub_type = folder_name=='main' ? 'original' : folder_name
        if action_type == "change"
          Image.find_by(imageable_id:product_id,imageable_type:"Product").destroy rescue nil
        end
        Image.save_and_upload(product_id, "Product", sub_type, image_path)
      else
        puts "#{folder_name} image not found for #{image_file_name}"
      end
    end
  end

  def image_list_for_product_page(sub_type)
    image_list= {
      additional: {
        thumb: [],
        main: [],
        original: []
      },
      original: [] ,
      display: [],
      flip: []
    }
    image_sub_type_order = {}
    images.each do |image|
      if image_sub_type_order[image.sub_type].present?
          image_sub_type_order[image.sub_type].push({"id":image.id,"name": image.image_file_name})
      else
          image_sub_type_order[image.sub_type]=[]
          image_sub_type_order[image.sub_type].push({"id":image.id,"name": image.image_file_name})
      end
    end
    if sub_type.present?
      image_sub_type_order[sub_type]
    else
      image_sub_type_order
    end
  end

  def self.solr_search(search_data, type,category_parent_id = nil)
   begin
     search = Product.search do
        any_of do
          if type=="category"
            with(:child_category_urls , search_data)
            with(:parent_category_url , search_data)
          elsif type=="wishlist"
            with(:id , search_data)
          elsif type=="collection"
           with(:collection_urls , search_data)
          end
           end
          with(:status,Product.statuses[:enabled])
          with(:child_category_status,Category.statuses[:enabled])
          with(:parent_category_status,Category.statuses[:enabled])
          if type=="collection"
          with(:collection_status,Collection.statuses[:enabled]) 
          end
          if category_parent_id.present? and category_parent_id == 123
            order_by :launched_timestamp, :desc
          elsif type=="category"
            order_by :category_rank, :desc
          else
            order_by :recommended_rank, :desc
          end
          paginate :page => 1, :per_page => 1000
        end
      hits = search.hits
   rescue Exception => e
     hits = []
   end
  end


  def self.reform_array(solr_result, is_search = 1, object = nil, is_display = 0, current_user = nil, device = "mobile_site", type = nil)
    category = {}
    if is_search == 0 and object.present?
      category[:id] = object.id
      category[:parent_id] = object.parent_id
      category[:image] = object.images.present? ? object.images[0].image_file_name : ""
      category[:name] = object.name
      category[:meta_title] = object.meta_title
      category[:meta_description] = object.meta_description
      category[:meta_keywords] = object.meta_keywords
      category[:canonical_url] = object.canonical_url
      category[:description] = object.description.present? ? eval(object.description)[:text] : ""
      if object.images.present?
        if device == "desktop"
          banner = object.images.desktop.present? ? object.images.desktop.first.image_file_name : nil
        else
          banner = object.images.mobilesite.present? ? object.images.mobilesite.first.image_file_name : nil
        end
      end
      category[:banner] = banner
    end
    rank = type == "category" ? "category_rank".to_sym : "recommended_rank".to_sym
    if object.present? and object.parent_id == 123
      category[:default_sortby] = "new"
    else
      category[:default_sortby] = ((type.present? and type == 'collection') ? "" : "Popular")
    end
    category[:notify_me_message] = "SELECT FROM UNAVAILABLE SIZES"
    category[:product_count] = 0
    category[:products]= []
    temp = ["id","name","description","url","mrp","price","rank","color_id","color_name","parent_category","child_category_url","sizes","flip_image","display_image","original_image","additional_image","is_mobile_cover","size_chart","status","in_stock","child_category","is_gift_card","product_description","fabric_detail","model_description","fit_description","delivery_and_return_policy","parent_category_id","child_category_id","tabular_description","parent_category_url"]
    lowest_price = 10000000000 # A very big number
    highest_price = 0
    category[:products].push(temp)
    filters = {}
    sizes = []
    all_sizes_keys =  APP_CONFIG["sizes"].keys.map(&:to_s)
    product_count = 0
    show_all_products = (current_user.present? and APP_CONFIG["show_all_products_users"].include?(current_user.email))
    total_out_of_stock_products = (solr_result.length/10)
    solr_result.each do |result|
      lowest_price = result.stored(:price)<lowest_price ? result.stored(:price) : lowest_price
      highest_price = result.stored(:price)>highest_price ? result.stored(:price) : highest_price
      in_stock, show_product = 0, 0 # Assuming all product_sizes are out of stock
      product_sizes = result.stored(:product_sizes)
      sorted_product_size_details=[]
      if product_sizes.present?
        sorted_product_size_details=product_sizes.sort_by{|product_size|
          product_size_id, size_name, avail = product_size.split("|")
          all_sizes_keys.index(size_name) || 0
        }
      end
      avail_sizes=[]
      if sorted_product_size_details.present?
        sorted_product_size_details.map { |product_size|
        product_size_id, size_name, avail = product_size.split("|")
        in_stock, show_product = 1, 1 if avail.to_i>0
        avail_sizes.push(size_name) if avail.to_i>0
        }
        sorted_product_size_details.each do |product_size|
          product_size_id, size_name, avail = product_size.split("|")
          if is_display==1
            if !show_all_products and size_name != "Standard" and (avail.to_i>0) and avail_sizes.count>1
              filters["sizes"] = filters["sizes"] || {}
              filters["sizes"][size_name] = filters["sizes"][size_name] || []
              filters["sizes"][size_name].push(result.stored(:id))
              sizes.push(size_name)
            end
          end
        end
      end
      if in_stock== 0 and total_out_of_stock_products > 0
        show_product = 1
        total_out_of_stock_products -= 1
      end

      flip_image = ""
      display_image = ""
      additional_image = []
      original_image = ""
      image_list_from_solr = result.stored(:images)
      if image_list_from_solr.present?
        image_list_from_solr.each do |image_data|
          image_name, priority, image_subtype = image_data.split("|")
          flip_image = image_name if image_subtype == "flip"
          display_image = image_name if image_subtype == "display"
          original_image = image_name if image_subtype == "original"
          additional_image.push(image_name) if image_subtype == "additional"
        end
      end
      category_array=[]
        category_array=(result.stored(:parent_category_ids) + result.stored(:child_category_ids)).uniq
      is_mobile_cover = result.stored(:parent_category_ids).first == 123 ? 1 : 0
      gift_card_categories=category_array & APP_CONFIG["gift_card_category"]
      is_gift_card=0
      is_gift_card=1  if gift_card_categories.present?
      # device = device == "desktop" ? device : "mobilesite"
      if device == "desktop"
      size_chart = APP_CONFIG["size_chart"][device][result.stored(:parent_category_ids).first] || ""
      else
      size_chart = APP_CONFIG["size_chart"]["mobilesite"][result.stored(:parent_category_ids).first] || ""
      end
      tabular_description = (eval(result.stored(:tabular_description)) || "")
      row = [result.stored(:id), result.stored(:name), result.stored(:description), result.stored(:url), result.stored(:mrp), result.stored(:price), (result.stored(rank) || 0), result.stored(:color_id),result.stored(:color_name) ,result.stored(:parent_category),result.stored(:child_category_urls).first , sorted_product_size_details, flip_image, display_image, original_image, additional_image, is_mobile_cover, size_chart, result.stored(:status), in_stock,result.stored(:child_category_names).first,is_gift_card,(result.stored(:product_description) || ""),(result.stored(:fabric_description) || ""), (result.stored(:model_description) || ""), (result.stored(:fit_description) || ""), result.stored(:delivery_and_return_policy),result.stored(:parent_category_ids).first,result.stored(:child_category_ids).first,tabular_description, result.stored(:parent_category_url)]
      if show_all_products or APP_CONFIG["products_with_out_of_stock"] == 1 or ((in_stock ==1 and avail_sizes.count >1) or show_product == 1) or is_mobile_cover==1 or is_gift_card==1 or type == "wishlist"
        category[:product_count] += 1
        if is_display==1
          product_filters = result.stored(:filters)
          if product_filters.present?
            product_filters.each do |product_filter|
              name, value = product_filter.split("|")
              filters[name] = filters[name] || {}
              filters[name][value] = filters[name][value] || []
              filters[name][value].push(result.stored(:id))
            end
          end
        end
        unless device=="android" and gift_card_categories.present?
          category[:products].push(row)
        end
      end
    end
    if is_display==1
      category[:lowest_price] = lowest_price
      category[:highest_price] = highest_price
      category[:sorted_sizes] = all_sizes_keys -(all_sizes_keys - sizes.uniq) - ["Standard"]
      category[:color_hex_codes] = APP_CONFIG["color_hex_codes"]
      category[:filters] = filters
      gender = ""
      if filters["gender"].present?
        gender = "Male" if filters["gender"]["male"].present? and !filters["gender"]["female"].present?
        gender = "Female" if filters["gender"]["female"].present? and !filters["gender"]["male"].present?
      end
      category[:gender] = gender
    end
    category
 end

  def self.bulk_upload_check(products_params)
    action_type = products_params["action_type"].split("bulk ").last
    sub_category = products_params["sub_category"].downcase.split(" mobile cover").first.lstrip
    sub_category = sub_category.split('/').first if sub_category.include? 'iphone'
    path =  APP_CONFIG["path_bulk#{action_type}"]+'/'+sub_category
    folders_exists = Dir.exists?(path)==true ? Dir["#{path}/*"]  : false
    if folders_exists
      folders_list = ["main","display","design_list.txt"]
      sub_folder = []
      folders_list.each do |folder_name|
        check_folder = ( folders_exists.include? "#{path}/#{folder_name}" ) ? "looks good" : "Cannot Find"
        sub_folder.push(check_folder)
      end
      if sub_folder.include?  "Cannot Find"
        return {"error": {"main folder":sub_folder[0],"display folder":sub_folder[1],"design list file":sub_folder[2] } }
      else
        bulk_files_process(path,sub_category,products_params,action_type)
      end
    else
      return  {"error":{"folder missing":"#{sub_category} folder missing" } }
    end
  end

  def self.bulk_files_process(path,sub_category,products_params,action_type)
    @file_missing = false
    folders_list,check_files = ["main","display"],{}
    folders_list.each do |folder_name|
    file_main_exists = ''
      count = 0
      File.open("#{path}/design_list.txt", "r").each_line do |line|
        count = count + 1
        design = line.strip+"_#{sub_category.gsub ' ','_'}_mobile_cover_#{folder_name}"
        design = design.gsub " ","_"
        File.exists?("#{path}/#{folder_name}/#{design}.jpg") ? ("looks good #{line.strip}") : ( @file_missing = true) && (file_main_exists += "#{line.strip}," )   
      end
       check_files = check_files.merge({"#{folder_name} file missing" =>  file_main_exists.chop})
    end
    @file_missing ? (return  "error" => check_files  ) : add_new_products(path,"#{sub_category}",products_params,action_type)
  end

  def self.add_new_products(path,sub_category,products_params,action_type)
    count_total_added,count_already_exist,count_total_error = 0,0,0
    products,product_exist_list,product_error_list = {},{},{}
    File.open("#{path}/design_list.txt", "r").each_line do |line|
      line = line.strip
      name = ("#{line} #{sub_category} Phone Case").titleize
      description = ""
      url = ("#{line}-phone-cases-for-#{sub_category}".gsub ' ','-').downcase
      product_exist = Product.find_by(url:url)
      if (product_exist and action_type == "upload")
        count_already_exist += 1
        product_exist_list.merge!("#{count_already_exist}":line)
      elsif ( !product_exist and action_type == "upload")
          meta_title = "#{sub_category.titleize} Mobile Covers/Cases – #{line.titleize} Online @Bewakoof.com"
          meta_description = "#{sub_category.titleize} mobile covers online in India at Bewakoof.com are sturdy & funky made for today’s youth. Visit us and buy your phone cases/covers. Free Shipping!"
        color_id = products_params["color_id"]
        price = products_params["price"]
        mrp = products_params["mrp"]
        status = products_params["status"] || 0
        weight = products_params["weight"]
        child_category_ids = products_params["sub_category_id"]
        product_hash =  {name:name, description:description, url:url, meta_title: meta_title,meta_description:meta_description, meta_keywords: nil, designer_id: nil, price:price, mrp:mrp, weight:weight,rank: 0, status: status, base_inventory: 1, color_id:color_id , child_category_ids:[child_category_ids] ,sizes:["Standard"]  }  
        @product = Product.new(product_hash)
      elsif product_exist and action_type == "change"
          @product = product_exist
      else
        @product = nil if action_type == "change"
       #none
      end
      sub_category = "#{sub_category}"
      image_file_name = "#{line}_#{sub_category}_mobile_cover".gsub ' ','_'
      if @product.present? && @product.save
        unless (product_exist && action_type == "upload")
          @product.image_upload(sub_category,image_file_name,action_type)
          count_total_added += 1
          products.merge!("#{count_total_added}":line)
        end
      elsif !product_exist
        count_total_error += 1
        product_error_list.merge!("#{count_total_error}":line)
      end
    end
    products_added = {"success":{count_product_added:count_total_added,count_already_exist:count_already_exist,count_product_error:count_total_error,product_added:products,product_already_exist:product_exist_list,product_error_list:product_error_list}}
  end

  def is_mobile_cover?
    ([123, 124].include?(child_categories.first.category.id)) rescue false
  end
  def model_description
    return nil
    return nil if is_mobile_cover?
    line = "Model is #{model.height} and wearing a #{model.size_top_name}" if model.present? and model.height.present? and model.size_top_name.present?
    line = "Model is 6' and wearing a Medium" if line.blank?  and filter_map["gender"] == "male"
    line = "Model is 5'7 and wearing a Small" if line.blank?  and filter_map["gender"] == "female"
    line
  end

  def product_description
    child_categories.first.product_description_mapping(filter_map) rescue nil
  end

  def dispatch_days
   self.child_categories.present? and self.child_categories.first.dispatch_days.present? ? "#{self.child_categories.first.dispatch_days}" : "7-10"
  end

  def delivery_and_return_policy
    "This product will be shipped in #{self.dispatch_days} business days.\n\n"+STATIC_CONFIG["delivery_shipping"]+"\n\n"+STATIC_CONFIG["return_policy"]
  end

  def fit_description
    Product.fit_descriptions[filter_map["fit"]] if filter_map["fit"].present?
  end

  def filter_map
    return @filter_map if @filter_map.present?
    @filter_map = {}
    filters.map {|filter| @filter_map[filter.name] = ((@filter_map[filter.name] || "") + " " + filter.value).strip}
    @filter_map
  end

  def fabric_detail
    material = filter_map['material']
    material = "100%" + material  if material == "cotton"
    "<b>Fabric</b>\n#{material}\n#{filter_map['fabric'].capitalize}\nPrewashed to impart a softer texture\n\n<b>Wash & Care</b>Do not iron directly on print\nMachine wash cold, tumble dry low\nProduct color may vary little due to photography \nWash with similar clothes" if filter_map['fabric'].present?
  end


  def self.fit_descriptions
    @fit_descriptions = @fit_descriptions || {
      boxy: "Boxy Fit: Hangs off the body",
      loose: "Loose Fit: Falls easy on your body, take your regular size \n\nSize down if a slimmer fit is desired",
      regular: "Regular Fit: Take your usual size",
      "regular slim": "Regular Slim Fit: Take your usual size",
      slim: "Slim Fit: Fits closer to the body, take your regular size \n\nSize up if a looser fit is desired"
    }.with_indifferent_access
  end

  def tabular_description(device = nil)
    description_details = {}
    description_details["product_description"] = {"name": "product_description","text": self.product_description, "image": []}
    description_details["fabric_detail"] = {"name": "fabric_detail","text": self.fabric_detail, "image": []}
    description_details["model_description"] = {"name": "model_description","text": self.model_description, "image": []}
    description_details["fit_description"] = {"name": "fit_description","text": self.fit_description, "image": []}
    category_description_img = self.child_categories.first.description_imagelist[device].present? ? [self.child_categories.first.description_imagelist[device]] : [] 
    description_details["product_size_and_specs"] = {"name": "Product Size and Specs","text": APP_CONFIG["mobilecovers_description"], "image": category_description_img} if category_description_img.present?
    description_details
  end
end
