Spree::Taxon.class_eval do
    # indicate which filters should be used for a taxon
    def applicable_filters
      fs = []
      #fs << Spree::Core::ProductFilters.taxons_below(self) unless self.root?
      #fs << Spree::Core::ProductFilters.brand_filter if Spree::Core::ProductFilters.respond_to?(:brand_filter)
      #fs << Spree::Core::ProductFilters.selective_brand_filter(self) if Spree::Core::ProductFilters.respond_to?(:selective_brand_filter)

      fs << Spree::Core::ProductFilters.sort_scope if Spree::Core::ProductFilters.respond_to?(:sort_scope)
      fs << Spree::Core::ProductFilters.price_range_filter if Spree::Core::ProductFilters.respond_to?(:price_range_filter)

      Spree::Property.all.each do |p|
        method_any = p.name.downcase + "_any"
        if Spree::Core::ProductFilters.respond_to?("#{method_any}_filter")
          fs << Spree::Core::ProductFilters.send("#{method_any}_filter", self)
        end
      end
      fs
    end
end
