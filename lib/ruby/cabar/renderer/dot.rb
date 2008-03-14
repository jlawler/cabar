require 'cabar/renderer'


module Cabar

  class Renderer

    # Renders as a dot graph.
    # See http://www.graphviz.org/
    class Dot < self
      attr_accessor :show_dependencies
      attr_accessor :show_facets
      attr_accessor :show_facet_names
      attr_accessor :show_facet_links
      attr_accessor :show_unrequired_components
      attr_accessor :show_all

      def initialize *args
        @show_dependencies = true
        @show_facets = false
        @show_facet_names = false
        @show_facet_links = false
        @show_unrequired_components = false

        super

        @show_facet_links &&= @show_facets
        if @show_all
          @show_dependencies =
          @show_facets =
          @show_facet_names =
          @show_facet_links =
          @show_unrequired_components =
            true
        end

        @dot_name = { }
        @dot_label = { }
        @required = { } # cache
        @current_directory = File.expand_path('.') + '/'
      end

      def render_Context cntx
        @context = cntx

        # Get list of all components.

        available_components = 
          cntx.
          available_components.to_a.
          sort { |a, b| a.name <=> b.name }

        components = available_components
        unless show_unrequired_components
          components = components.select do | c |
            @context.required_component? c
          end
        end

        @components = components

        # Get list of all facets.
        facets =
        components.
        map { | c |
          c.facets
        }.flatten.
        map { | f |
          f._proto
        }.uniq.sort_by{|x| x.key}
        @facets = facets

        # Delay edges until end.
        @edges = [ ]
        @subgraph = 0

        puts "digraph Cabar {"
        puts "  overlap=false;"
        puts "  splines=true;"

#        puts ""
#        puts "  // components as nodes"
#        components.each do | c |
#          render c
#        end

        puts ""
        puts "  // component version grouping"
        components.map{ | c | c.name}.uniq.each do | c_name |
          versions = components.select{ | c | c.name == c_name }
          # next if versions.size < 2

          a = versions.first
          a_name = dot_name a, :version => false

          # Get all versions of
          # component a.
          available_a = 
            available_components.
            select{|c| c.name == a.name }

          # Show all versions available in a tooltip.
          tooltip = "available: " + 
            available_a.
            sort{|a,b| a.version <=> b.version}.
            reverse.
            map{|v| v.version.to_s }.join(', ')
          tooltip = tooltip.inspect
          
          # Are any versions of a required?
          any_required = available_a.any?{|c| required? c}

          # Make a subgraph of all versions of component a.
          puts ""
          puts "// #{a_name}"
          puts "  subgraph sg_#{@subgraph += 1} {"
          puts "    label=#{a.name.inspect};"
          puts "    color=black;"
          puts "    style=solid;"
 
          puts "    node [ shape=box, style=#{any_required ? :solid : :dotted}, label=#{"#{c_name}".inspect}, tooltip=#{tooltip} ] #{a_name};"

          versions.each do | c_v |
            render c_v
#            
#            b = dot_name c_v
#            edge_puts "    #{a_name} -> #{b} [ style=dotted, arrowhead=none ];" 
          end
          puts "  }"
          puts ""

          edge_puts ""
          edge_puts "// component #{a.name.inspect} versions as edges"
          versions.each do | c_v |
            b = dot_name c_v
            edge_puts "    #{a_name} -> #{b} [ style=dotted, arrowhead=none ];" 
          end

        end

        puts ""
        puts "  // facets as nodes"
        facets.each do | f |
          render f
        end

        edge_puts ""
        edge_puts "  // dependencies as edges"
        components.each do | c |
          c.requires.each do | d |
            render_dependency_link d
          end
        end

        edge_puts ""
        edge_puts "  // facet usages as edges"
        components.each do | c |
          c.facets.each do | f |
            render_facet_link c, f
          end
        end

        # Render all edges.
        @edges.each do | e |
          puts e
        end

        puts ""
        puts "// END"
        puts "}"
      end

      def render_Component c
        # $stderr.puts "render_Component #{c}"
        required = required? c
        style = "solid"
        style = "dotted" unless required
        tooltip = (c.description || c.to_s(:short)).inspect
        puts "  node [ shape=box, label=#{dot_label c}, tooltip=#{tooltip}, style=#{style}, URL=#{('file://' + c.directory).inspect} ] #{dot_name c};"
      end

      def render_Facet f
        # $stderr.puts "render_Facet #{f.class}"
        return unless show_facets
        return if Cabar::Facet::RequiredComponent === f
        puts "  node [ shape=hexagon, label=#{dot_label f} ] #{dot_name f};"
      end

      def render_dependency_link d
        return unless show_dependencies

        c1 = d.component
        c2 = d.resolved_component

        return unless c1 && c2 &&
          @components.include?(c1) &&
          @components.include?(c2)

        edge_puts "  #{dot_name c1} -> #{dot_name c2, :version => false} [ style=dotted, arrowhead=open ];"

        edge_puts "  #{dot_name c1} -> #{dot_name c2} [ label=#{dot_label d}, #{required?(c1) && required?(c2) ? '' : 'style=dotted, '} arrowhead=normal ];"

      end

      def render_facet_link c, f
        return if Cabar::Facet::RequiredComponent === f
        return unless show_facet_links
        edge_puts "  #{dot_name c} -> #{dot_name f} [ style=dotted, arrowhead=none ];"
      end

      def required? c
        @required[c.object_id] ||=
          [ @context.required_component?(c) ].first
      end

      def edge_puts x
        if @edges
          @edges << x.to_s
        else
          puts x.to_s
        end
      end

      # Returns the dot node or edge name for an object.
      def dot_name x, opts = EMPTY_HASH
        @dot_name[[ x, opts ]] ||=
          case x
          when Cabar::Component
            prefix = ''
            if opts[:subgraph]
              opts[:version] = false
              prefix = "SG "
            end

            prefix +
            case opts[:version]
            when false
              "C #{x.name}"
            else
              "C #{x.name} #{x.version}"
            end
          when Cabar::Facet
            "F #{x.key}"
          else
            "X #{x}"
          end.
          inspect
      end


      # Returns the dot node or edge label for an object.
      def dot_label x, opts = EMPTY_HASH
        @dot_label[[x, opts]] ||=
          case x
          when Cabar::Component
            # * name and version
            # * directory
            # * facets (optional)
            dir = x.directory.sub(/^#{@current_directory}/, './')
            str = ''
            str << "#{x.name}"
            str << " #{x.version}" if opts[:version] != false
            str << "\\n#{dir}"
            if show_facet_names && opts[:show_facet_names] != false
              str << "\\n"
              # <- <<exported facet name>>
              x.provides.
                map{|f| f.key}.
                sort.
                each{|f| str << "<- #{f}\\l"}

              # <* <<plugin name>>
              x.plugins.
                map{|p| p.name}.
                sort.
                map{|p| p.sub(/\/.*$/, '/*')}.
                uniq.
                each{|p| str << "<* #{p}\\l"}
            end
            '"' + str + '"'
          when Cabar::Facet::RequiredComponent
            # Use the version requirement.
            x._proto ? "#{x.version}".inspect : x.key.to_s.inspect
          when Cabar::Facet
            # Use the facet name.
            x.key.to_s.inspect
          else
            x.to_s.inspect
          end
      end

    end # class

  end # class
  
end # module

