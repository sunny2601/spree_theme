Spree::OrdersController.class_eval do
respond_to :html, :js
 
  # override populate method
  def populate
#    fire_event('spree.cart.add')
#    fire_event('spree.order.contents_changed')

#    params[:products].each do |product_id,variant_id|
#      quantity = params[:quantity].to_f if !params[:quantity].is_a?(Hash)
#      quantity = params[:quantity][variant_id].to_f if params[:quantity].is_a?(Hash)
#      @order.add_variant(Variant.find(variant_id), quantity) if quantity > 0
#    end if params[:products]
#    params[:variants].each do |variant_id, quantity|
#      quantity = quantity.to_f
#      @order.add_variant(Variant.find(variant_id), quantity) if quantity > 0
#    end if params[:variants]

    params[:quantity] ||= 1

    populator = Spree::OrderPopulator.new(current_order(create_order_if_necessary: true), current_currency)
    if populator.populate(params[:variant_id], params[:quantity])
      current_order.ensure_updated_shipments

      #flash[:success] = handler.success
      variant = Spree::Variant.find(params[:variant_id])
      product = variant.product
#ActionController::Base.helpers
      populate_json = { name: product.name, image: view_context.link_to(view_context.product_image(product, itemprop: "image"), product, class: "dialog-image-link", itemprop: 'url'), price: view_context.display_price(variant), original_price: '' }

#@order.contents.add(variant, quantity, options.merge(currency: currency))
      order = current_order(create_order_if_necessary: true)
      line_item = order.find_line_item_by_variant(variant)

      unless line_item.price == variant.price
        populate_json[:price] = line_item.single_money.to_html
        populate_json[:original_price] = view_context.display_price(variant)
      end

#      @order.line_items.
#if variant
#.select(&:service?)
#find

      respond_with(@order) do |format|
        format.html { redirect_to cart_path }
        format.json { render json: populate_json.to_json }
      end
    else
      flash[:error] = populator.errors.full_messages.join(" ")
      redirect_to :back
    end
  end

private

  def add
#    redirect_to action: :populate
#    flash[:notice] = "Added #{variant.name} to cart"

    respond_to do | format |
      format.js { render action: 'edit' }
    end
  end



  def adds
    @order = current_order(true)
    variant = Variant.find(params[:variant_id])
    
    @order.add_variant(variant, 1)
    flash[:notice] = "Added #{variant.name} to cart"

    respond_to do | format |
      format.js { render :action => 'edit' }
    end
  end

  def updates
    @order = current_order
    if @order.update_attributes(params[:order])
      @order.line_items = @order.line_items.select {|li| li.quantity > 0 }
      respond_to do |format|
        format.html { redirect_to cart_path }
        format.js { render :action => 'edit' }
      end
    else
      render :edit
    end
  end
end
