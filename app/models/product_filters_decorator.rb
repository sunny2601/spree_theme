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

      Spree::Product.class_eval do #.add_search_scope :ascend_by_name do |name|
        cname = "#{Product.quoted_table_name}.name"
        self.scope("ascend_by_name", -> { select("CASE WHEN (INSTR(LOWER(#{cname}), 'a ') = 1) THEN SUBSTR(LOWER(#{cname}), 3) WHEN (INSTR(LOWER(#{cname}), 'an ') = 1) THEN SUBSTR(LOWER(#{cname}), 4) WHEN (INSTR(LOWER(#{cname}), 'the ') = 1) THEN SUBSTR(LOWER(#{cname}), 5) ELSE LOWER(#{cname}) END as `sort_name`").order("`sort_name` ASC") })
      #end
      #Spree::Product.class_eval do #.add_search_scope :descend_by_name do
        #cname = "#{Product.quoted_table_name}.name"
        self.scope("descend_by_name", -> { select("CASE WHEN (INSTR(LOWER(#{cname}), 'a ') = 1) THEN SUBSTR(LOWER(#{cname}), 3) WHEN (INSTR(LOWER(#{cname}), 'an ') = 1) THEN SUBSTR(LOWER(#{cname}), 4) WHEN (INSTR(LOWER(#{cname}), 'the ') = 1) THEN SUBSTR(LOWER(#{cname}), 5) ELSE LOWER(#{cname}) END as `sort_name`").order("`sort_name` DESC") })
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

      # Filter by price range
      Spree::Product.add_search_scope :price_range do |*opts|
        return all if opts.all?(&:blank?) || opts.length < 2
        opts[0] = opts[0].blank? || opts[0].to_f < 0 ? "0" : opts[0]
        price_between(*opts)
      end

      def ProductFilters.price_range_filter
        {
          name:   Spree.t(:price_range),
          scope:  :price_range,
          labels: [" to ", ""]
        }
      end


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
          return all if scope.all?(&:blank?)
          table_alias = "#{method_any}_alias"
          joins('INNER JOIN `spree_product_properties` AS `' + table_alias + '` ON `' + table_alias + '`.`product_id` = `spree_products`.`id`').where(table_alias => { value: scope})
          #joins(:product_properties).where(Spree::ProductProperty.table_name => { value: scope})
        end

        #self.singleton_class.send :define_method,
        define_singleton_method :"#{method_any}_filter" do |taxon|
          #taxon ||= Spree::Taxonomy.first.root
          #pp = Spree::ProductProperty.arel_table.alias("#{method_any}_alias")
          #conds = Hash[*props.map{ |b| b.split(", ").map{|s| [s, pp[:value].eq(b)]} }.flatten]

          props = Spree::ProductProperty.where(property_id: p.id).pluck(:value).uniq.map(&:to_s).reject(&:blank?) if taxon.nil?
          props = Spree::ProductProperty.where(property_id: p.id).joins(product: :taxons).where("#{Spree::Taxon.table_name}.id" => [taxon] + taxon.descendants).pluck(:value).uniq.map(&:to_s).reject(&:blank?) if !taxon.nil?

          conds = Hash[*props.map{ |b| b.split(",").map{|s| [s.strip, b]} }.flatten]
          props = props.map{|o| o.split(",").map(&:strip)}.flatten.sort
          {
            name:   p.name,
            scope:  method_any,
            conds:  conds,
            labels: props.map { |k| [k, k] }.uniq
          }
        end
      end


    end
  end
end
