require 'cabar/renderer'


module Cabar

  class Renderer

    # Renders as a dot graph.
    # See http://www.graphviz.org/
    class Dot < self
      # Options:
      attr_accessor :show_dependencies
      attr_accessor :group_component_versions
      attr_accessor :show_facets
      attr_accessor :show_facet_names
      attr_accessor :show_facet_links
      attr_accessor :show_unrequired_components
      attr_accessor :show_all

      def initialize *args
        @group_component_versions = false
        @show_dependencies = true
        @show_facets = false
        @show_facet_names = false
        @show_facet_links = false
        @show_unrequired_components = false

        super

        @show_facet_links &&= @show_facets
        if @show_all
          @group_component_versions =
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

        # Delay output of edges.
        @edges = [ ]

        puts "digraph cabar {"
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

          if group_component_versions
            # Show all versions available in a tooltip.
            tooltip = "available: " + 
              available_a.
              sort{|a,b| a.version <=> b.version}.
              reverse.
              map{|v| (required?(v) ? '*' : EMPTY_STRING) + v.version.to_s }.join(', ')
            tooltip = tooltip.inspect
            
            # Are any versions of a required?
            any_required = available_a.any?{|c| required? c}
            
            # Make a subgraph of all versions of component a.
            puts ""
            puts "// #{a_name} #{a.name}"
            puts "  subgraph #{dot_name a, :subgraph => true} {"
            puts "    label=#{a.name.inspect};"
            #puts "    label=#{a.name.inspect};"
            #puts "    color=black;"
            #puts "    style=solid;"
            
            render_node a_name, 
            :shape => :box,
            :style => any_required ? :solid : :dotted, 
            :label => a.name, 
            :tooltip => tooltip
          end

          versions.each do | c_v |
            render c_v
            if group_component_versions
              render_edge a_name, c_v, 
              :style => :dotted, 
              :arrowhead => :none,
              :comment => "component #{a.name.inspect} version relationship" 
            end
          end

          if group_component_versions
            puts "  }"
            puts ""
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

      def render_Component c, opts = nil
        opts ||= EMPTY_HASH
        # $stderr.puts "render_Component #{c}"

        opts = {
          :shape => :box,
          :label => dot_label(c),
          :tooltip => (c.description || c.to_s(:short)),
          :style => required?(c) ? :solid : :dotted,
          :URL => 'file://' + c.directory,
        }
                 
        if group_component_versions
          opts[:in_subgraph] = true
        end

        render_node dot_name(c), opts
      end

      def render_Facet f
        # $stderr.puts "render_Facet #{f.class}"
        return unless show_facets
        return if Cabar::Facet::RequiredComponent === f
        render_node f, :shape => :hexagon, :label => dot_label(f)
      end

      def render_dependency_link d
        return unless show_dependencies

        c1 = d.component
        c2 = d.resolved_component

        return unless c1 && c2 &&
          @components.include?(c1) &&
          @components.include?(c2)

        if group_component_versions
          render_edge c1, dot_name(c2, :version => false),
          :style => :dotted, 
          :arrowhead => :open
        end

        render_edge c1, c2,
        :label => dot_label(d),
        :arrowhead => :normal,
        :style => required?(c1) && required?(c2) ? nil : :dotted
      end

      def render_facet_link c, f
        return if Cabar::Facet::RequiredComponent === f
        return unless show_facet_links
        render_edge c, f, :style => :dotted, :arrowhead => :none
      end

      def render_node name, opts = nil
        opts ||= EMPTY_HASH
        name = dot_name(name) unless String === name
        prefix = name
        suffix = EMPTY_STRING

        if true || opts[:in_subgraph]
          opts.delete(:in_subgraph) rescue nil
          prefix = 'node'
          suffix = name
        end

        if opts[:comment]
          edge_puts "// #{opts[:comment]}"
          opts.delete(:comment)
        end

        puts "    #{prefix} #{dot_opts opts} #{suffix};"
      end

      def render_edge n1, n2, opts = nil
        opts ||= EMPTY_HASH

        n1 = dot_name(n1) unless String === n1
        n2 = dot_name(n2) unless String === n2

        if opts[:comment]
          edge_puts "// #{opts[:comment]}"
          opts.delete(:comment)
        end

        edge_puts "    #{n1} -> #{n2} #{dot_opts opts};"
      end

      # Options with nil values are not expanded.
      def dot_opts opts = nil
        opts ||= EMPTY_HASH
        unless opts.empty?
          "[ #{opts.map{|k, v| v.nil? ? nil : "#{k}=#{v.to_s.inspect.gsub(/\\\\/, '\\')}"}.compact.join(', ')} ]"
        else
          EMPTY_STRING
        end
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
            prefix = EMPTY_STRING
            if opts[:subgraph]
              opts[:version] = false
              prefix = "s"
            end

            prefix +
            case opts[:version]
            when false
              "c #{x.name}"
            else
              "c #{x.name} #{x.version}"
            end
          when Cabar::Facet
            "f #{x.key}"
          else
            "x #{x}"
          end.
          sub(/([a-z]+) (.*)/i){|| "#{$1}_#{$2.hash}"}.
          gsub('-', '_') 
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
            str << "\n#{dir}"
            if show_facet_names && opts[:show_facet_names] != false
              str << "\n"
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
            # '"' + str + '"'
            str
          when Cabar::Facet::RequiredComponent
            # Use the version requirement.
            x._proto ? "#{x.version}" : x.key
          when Cabar::Facet
            # Use the facet name.
            x.key.to_s
          else
            x.to_s
          end
      end

    end # class

  end # class
  
end # module

