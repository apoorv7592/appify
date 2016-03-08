class V1::Admin::ProductsController < V1::AdminController
  before_action :set_product, only: [:show, :update, :destroy]

  # GET /products
  # GET /products.json
  def index
    @products = Product.all
  end
  # GET /products/1
  # GET /products/1.json
  def show
  end
  # POST /products
  # POST /products.json
  def create
    @product = Product.new(product_params)
    @product.sizes = params[:product][:sizes]
    if @product.save
       render json: @product, status: :created
    else
       render_api_error(0, 422, 'error', @product.errors) 
    end
  end

  # PATCH/PUT /products/1
  # PATCH/PUT /products/1.json
  def update
      @product.sizes = params[:product][:sizes]
      if @product.update(product_params)
        update_product_filter
        render json: @product, status: :ok
      else
        render_api_error(0, 422, 'error', @product.errors) 
      end
  end

  # POST /products/bulk_upload_file
  #body  {"products":{"zip_file": FILE}}
  def bulk_upload_file
    zip_file = params["products"]["zip_file"]
    if zip_file.content_type == "application/zip"
    FileZip.unzip(zip_file.tempfile, APP_CONFIG["path_bulkupload"])
      render json: {"status": "File uploaded successfully"}
    else
      render json: {"error": "Incorrect file format"}
    end
  end
  
  # POST /products/bulk_upload 
  #body  {"products":{"sub_category":"iphone 4 mobile covers","sub_category_id":132,"price":500,"mrp":500,"weight":20,"status":0,"color_id":23}}
  def bulk_upload
    products_params = params["products"]
    result = Product.bulk_upload_check(products_params) 
    render json: result
  end


  private
    # Use callbacks to share common setup or constraints between actions.
    def set_product
      if params[:id] =~ /[[:alpha:]]/
        @product = Product.find_by(:url => params[:id])
      else
        @product = Product.find(params[:id])
      end
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def product_params
       product_params =  params.require(:product).permit(:name, :description, :url, :meta_title, :meta_description, :meta_keywords, :designer_id, :price, :mrp, :weight, :rank, :status, :base_inventory, :color_id, :filters,:model_id, child_category_ids: [])
       product_params[:update_by_admin_user] = current_user
       product_params
    end

end
