


Cabar::Plugin.new :name => 'cabar/component', :documentation => <<'DOC' do
Component support.
DOC

  require 'cabar/command/standard' # Standard command support.
  require 'cabar/facet/standard'   # Standard facets and support.
  require 'cabar/renderer/dot'     # Dot graph support.

  ##################################################################
  # Component commands
  #

  facet :required_component, :class => Cabar::Facet::RequiredComponent
  
  cmd_group [ :component, :comp, :c ] do
    cmd [ :list, :ls ], <<'DOC' do
[ --verbose ] [ - <component> ]
Lists all available components.
DOC
      yaml_renderer.
        render_components(context.
                          available_components.
                          select(search_opts(cmd_args))
                          )
    end

    cmd :facet, <<'DOC' do
[ - <component> ]
Show the facets for the top-level component.
DOC
      select_root cmd_args
      
      yaml_renderer.
        render_facets(context.
                      facets.
                      values
                      )
    end
    
    cmd :dot, <<'DOC' do
[ - <component> ]
Render the components as a dot graph on STDOUT.
DOC
      select_root cmd_args
      
      r = Cabar::Renderer::Dot.new cmd_opts
      
      r.render(context)
    end
    
    cmd :show, <<'DOC' do
[ <cmd-opts???> ] [ - <component> ]
Lists the current settings for a selected component.
DOC
      select_root cmd_args
      
      yaml_renderer.
        render_components(context.required_components)
      yaml_renderer.
        render_facets(context.facets.values)
    end
    
  end # cmd_group
  

  ##################################################################
  # Recursive subcomponents.
  #

  facet :components, 
    :class => Cabar::Facet::Components,
    :path => [ 'comp' ],
    :inferrable => true

end # plugin

