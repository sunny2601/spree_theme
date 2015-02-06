Spree::TaxonsHelper.class_eval do
    # Retrieves the collection of products to display when "previewing" a taxon.  This is abstracted into a helper so
    # that we can use configurations as well as make it easier for end users to override this determination.  One idea is
    # to show the most popular products for a particular taxon (that is an exercise left to the developer.)
    def taxon_preview(products, taxon, max=4)
      products.joins(:taxons).where("#{Spree::Taxon.table_name}.id" => [taxon] + taxon.descendants).limit(max) - [:num_pages]
    end

    def taxon_nav(root_taxon, current_taxon, max_level = 1)
      return '' if root_taxon.children.empty?
      #return '' if max_level < 1 || root_taxon.children.empty?
      content_tag :ul, class: 'taxons-list' do
        root_taxon.children.map do |taxon|
          css_class = (current_taxon && current_taxon.eql?(taxon)) ? 'current' : ( current_taxon.self_and_ancestors.include?(taxon) ? 'parent' : nil)
          content_tag :li, class: css_class do
            if css_class == 'current'
              content_tag(:strong, taxon.name) + taxon_nav(taxon, current_taxon, max_level - 1)
            else
              link_to(taxon.name, params.merge(id: taxon.permalink)) + taxon_nav(taxon, current_taxon, max_level - 1)
            end
          end
        end.join("\n").html_safe
      end
    end
end
