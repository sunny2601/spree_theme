Spree::BaseHelper.class_eval do

#old_link_to_cart = instance_method(:link_to_cart)
#  define_method(:link_to_cart) do
#    old_link_to_cart.bind(self).call
  def link_to_cart(text = nil)
      text = text ? h(text) : Spree.t('cart')
      css_class = nil

      if simple_current_order.nil? or simple_current_order.item_count.zero?
        text = "#{text}: (#{Spree.t('empty')})"
        css_class = 'empty'
      else
        text = "#{text}: (#{simple_current_order.item_count}) <span class='amount'>#{simple_current_order.display_total.to_html}</span>"
        css_class = 'full'
      end
      text = "<i class='icon-basket'></i> #{text}"
      link_to text.html_safe, spree.cart_path, :class => "cart-info #{css_class}"
  end
end
