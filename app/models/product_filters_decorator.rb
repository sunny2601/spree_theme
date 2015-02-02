module Spree
  module Core
    # Each filter has two parts
    #  * a parametrized named scope which expects a list of labels
    #  * an object which describes/defines the filter
    #
    # The filter description has three components
    #  * a name, for displaying on pages
    #  * a named scope which will 'execute' the filter
    #  * a mapping of presentation labels to the relevant condition (in the context of the named scope)
    #  * an optional list of labels and values (for use with object selection - see taxons examples below)
    #
    # The named scopes here have a suffix '_any', following Ransack's convention for a
    # scope which returns results which match any of the inputs. This is purely a convention,
    # but might be a useful reminder.
    #
    # When creating a form, the name of the checkbox group for a filter F should be
    # the name of F's scope with [] appended, eg "price_range_any[]", and for
    # each label you should have a checkbox with the label as its value. On submission,
    # Rails will send the action a hash containing (among other things) an array named
    # after the scope whose values are the active labels.
    #
    # Ransack will then convert this array to a call to the named scope with the array
    # contents, and the named scope will build a query with the disjunction of the conditions
    # relating to the labels, all relative to the scope's context.
    #
    # The details of how/when filters are used is a detail for specific models (eg products
    # or taxons), eg see the taxon model/controller.
    module ProductFilters

      Spree::Product.add_search_scope :in_taxon do |taxon|
        includes(:classifications).
        where("spree_products_taxons.taxon_id" => taxon.self_and_descendants.pluck(:id)).
        ascend_by_name
      end

      #reorder()
      Spree::Product.add_search_scope :sort_by do |*opts|
        return unscope(:order).ascend_by_name if opts.all?(&:blank?)
        unscope(:order).send(ProductFilters.sort_scope[:conds][opts.shift][1])
      end

      def ProductFilters.sort_scope
        conds = {"price-asc" => ["Price: Lowest First", "ascend_by_master_price"], "price-desc" => ["Price: Highest First", "descend_by_master_price"], "name-asc" => ["Name: A-Z", "ascend_by_name"], "name-desc" => ["Name: Z-A", "descend_by_name"], "popular-desc" => ["Popularity", "descend_by_popularity"] }#, "Year Released" => "descend_by_popularity"
        {
          name:   Spree.t(:sort_by),
          scope:  :sort_by,
          labels: conds.map { |k,v| [v[0], k] },
          conds:  conds
        }
      end

      # Example: filtering by price
      #   The named scope just maps incoming labels onto their conditions, and builds the conjunction
      #   'price' is in the base scope's context (ie, "select foo from products where ...") so
      #     we can access the field right away
      #   The filter identifies which scope to use, then sets the conditions for each price range
      Spree::Product.add_search_scope :price_range do |*opts|
        opts[0] = opts[0].blank? || opts[0].to_f < 0 ? "0" : opts[0]
        return all if opts.all?(&:blank?) || opts.length < 2
        price_between(*opts)
      end

      #def ProductFilters.format_price(amount)
      #  Spree::Money.new(amount)
      #end

      def ProductFilters.price_range_filter
        {
          name:   Spree.t(:price_range),
          scope:  :price_range,
          labels: [" to ", ""]
        }
      end


      # Example: filtering by possible brands
      #
      # First, we define the scope. Two interesting points here: (a) we run our conditions
      #   in the scope where the info for the 'brand' property has been loaded; and (b)
      #   because we may want to filter by other properties too, we give this part of the
      #   query a unique name (which must be used in the associated conditions too).
      #
      # Secondly, the filter. Instead of a static list of values, we pull out all existing
      #   brands from the db, and then build conditions which test for string equality on
      #   the (uniquely named) field "p_brand.value". There's also a test for brand info
      #   being blank: note that this relies on with_property doing a left outer join
      #   rather than an inner join.
      #Spree::Product.add_search_scope :brand_any do |*opts|
      #  conds = opts.map {|o| ProductFilters.brand_filter[:conds][o]}.reject { |c| c.nil? }
      #  scope = conds.shift
      #  conds.each do |new_scope|
      #    scope = scope.or(new_scope)
      #  end
      #  Spree::Product.with_property('brand').where(scope)
      #end

      #def ProductFilters.brand_filter
      #  brand_property = Spree::Property.find_by(name: 'brand')
      #  brands = brand_property ? Spree::ProductProperty.where(property_id: brand_property.id).pluck(:value).uniq.map(&:to_s) : []
      #  pp = Spree::ProductProperty.arel_table
      #  conds = Hash[*brands.map { |b| [b, pp[:value].eq(b)] }.flatten]
      #  {
      #    name:   'Brands',
      #    scope:  :brand_any,
      #    conds:  conds,
      #    labels: (brands.sort).map { |k| [k, k] }
      #  }
      #end

      # Example: a parameterized filter
      #   The filter above may show brands which aren't applicable to the current taxon,
      #   so this one only shows the brands that are relevant to a particular taxon and
      #   its descendants.
      #
      #   We don't have to give a new scope since the conditions here are a subset of the
      #   more general filter, so decoding will still work - as long as the filters on a
      #   page all have unique names (ie, you can't use the two brand filters together
      #   if they use the same scope). To be safe, the code uses a copy of the scope.
      #
      #   HOWEVER: what happens if we want a more precise scope?  we can't pass
      #   parametrized scope names to Ransack, only atomic names, so couldn't ask
      #   for taxon T's customized filter to be used. BUT: we can arrange for the form
      #   to pass back a hash instead of an array, where the key acts as the (taxon)
      #   parameter and value is its label array, and then get a modified named scope
      #   to get its conditions from a particular filter.
      #
      #   The brand-finding code can be simplified if a few more named scopes were added to
      #   the product properties model.
      #Spree::Product.add_search_scope :selective_brand_any do |*opts|
      #  Spree::Product.brand_any(*opts)
      #end

      #def ProductFilters.selective_brand_filter(taxon = nil)
      #  taxon ||= Spree::Taxonomy.first.root
      #  brand_property = Spree::Property.find_by(name: 'brand')
      #  scope = Spree::ProductProperty.where(property: brand_property).
      #    joins(product: :taxons).
      #    where("#{Spree::Taxon.table_name}.id" => [taxon] + taxon.descendants)
      #  brands = scope.pluck(:value).uniq
      #  {
      #    name:   'Applicable Brands',
      #    scope:  :selective_brand_any,
      #    labels: brands.sort.map { |k| [k, k] }
      #  }
      #end
      #Spree::Taxon.find(params[:taxon]) @properties[:taxon]

      Spree::Property.all.each do |p|
        method_any = p.name.downcase + "_any"
        Spree::Product.add_search_scope method_any do |*opts|
          conds = ProductFilters.send("#{method_any}_filter", nil)[:conds]

          #conds = opts.map {|o| conds[o] }.reject(&:blank?)
          #scope = conds.shift
          #conds.each do |new_scope|
          #  scope = scope.or(new_scope)
          #end
          #with_property(p.name).where(scope)

          #scope = opts.reject{|o| !props.include?(o) }
          scope = opts.map {|o| conds[o] }.reject(&:blank?).uniq
          return scoped if scope.all?(&:blank?)
          table_alias = "#{method_any}_alias"
          joins('INNER JOIN "spree_product_properties" AS "' + table_alias + '" ON "' + table_alias + '"."product_id" = "spree_products"."id"').where(table_alias => { value: scope})
          #joins(:product_properties).where(Spree::ProductProperty.table_name => { value: scope})
        end

        #self.singleton_class.send :define_method,
        define_singleton_method :"#{method_any}_filter" do |taxon|
          #taxon ||= Spree::Taxonomy.first.root
          #pp = Spree::ProductProperty.arel_table.alias("#{method_any}_alias")
          #conds = Hash[*props.map{ |b| b.split(", ").map{|s| [s, pp[:value].eq(b)]} }.flatten]

          props = Spree::ProductProperty.where(property_id: p.id).pluck(:value).uniq.map(&:to_s).reject(&:blank?) if taxon.nil?
          props = Spree::ProductProperty.where(property_id: p.id).joins(product: :taxons).where("#{Spree::Taxon.table_name}.id" => [taxon] + taxon.descendants).pluck(:value).uniq.map(&:to_s).reject(&:blank?) if !taxon.nil?

          conds = Hash[*props.map{ |b| b.split(", ").map{|s| [s, b]} }.flatten]
          props = props.map{|o| o.split(", ")}.flatten.sort
          {
            name:   p.name,
            scope:  method_any,
            conds:  conds,
            labels: props.map { |k| [k, k] }
          }
        end
      end

      # Provide filtering on the immediate children of a taxon
      #
      # This doesn't fit the pattern of the examples above, so there's a few changes.
      # Firstly, it uses an existing scope which was not built for filtering - and so
      # has no need of a conditions mapping, and secondly, it has a mapping of name
      # to the argument type expected by the other scope.
      #
      # This technique is useful for filtering on objects (by passing ids) or with a
      # scope that can be used directly (eg. testing only ever on a single property).
      #
      # This scope selects products in any of the active taxons or their children.
      #
      def ProductFilters.taxons_below(taxon)
        return Spree::Core::ProductFilters.all_taxons if taxon.nil?
        {
          name:   'Taxons under ' + taxon.name,
          scope:  :taxons_id_in_tree_any,
          labels: taxon.children.sort_by(&:position).map { |t| [t.name, t.id] },
          conds:  nil
        }
      end

      # Filtering by the list of all taxons
      #
      # Similar idea as above, but we don't want the descendants' products, hence
      # it uses one of the auto-generated scopes from Ransack.
      #
      # idea: expand the format to allow nesting of labels?
      def ProductFilters.all_taxons
        taxons = Spree::Taxonomy.all.map { |t| [t.root] + t.root.descendants }.flatten
        {
          name:   'All taxons',
          scope:  :taxons_id_equals_any,
          labels: taxons.sort_by(&:name).map { |t| [t.name, t.id] },
          conds:  nil # not needed
        }
      end
    end
  end
end
