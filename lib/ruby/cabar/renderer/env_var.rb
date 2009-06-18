require 'cabar/renderer'


module Cabar

  # Base class for rendering methods of Components and Facets.
  class Renderer

    # Abstract superclass for rendering environment variables.
    class EnvVar < self
      attr_accessor :env_var_prefix

      def initialize *args
        @env_var_prefix ||= ''
        super
      end


      # Calls Cabar.path_sep.
      def path_sep
        Cabar.path_sep
      end


      # Renders a Resolver object,
      # Using the Resolver's current required_components_dependencies.
      #
      def render_Resolver x
        comment "Cabar config"

        comps = x.required_component_dependencies
        
        self.env_var_prefix = "CABAR_"
        setenv "TOP_LEVEL_COMPONENTS", x.top_level_components.map{ | c | c.name }.join(" ")
        
        setenv "REQUIRED_COMPONENTS", comps.map{ | c | c.name }.join(" ")
        render comps

        comment nil
        comment "Cabar General Environment"
        
        render x.facets.values
      end
      

      def render_Selection x
        if _options[:selected]
          render x.to_a
        else
          render x.resolver
        end
      end


      def render_Array_of_Component comps, opts = EMPTY_HASH
        comps.each do | c |
          comment nil
          comment "Cabar component #{c.name}"
          self.env_var_prefix = "CABAR_#{c.name}_"
          setenv :NAME, c.name
          setenv :VERSION, c.version
          setenv :DIRECTORY, c.directory
          setenv :BASE_DIRECTORY, c.base_directory
          c.provides.each do | facet |
            comment nil
            comment "facet #{facet.key.to_s.inspect}"
            facet.render self
          end
          c.configuration.each do | k, v |
            comment "config #{k.to_s.inspect}"
            setenv "CONFIG_#{k}", "#{v}"
          end          
        end
      end


      def render_Array_of_Facet facets, opts = EMPTY_HASH
        self.env_var_prefix = ''
        
        #render application level env_vars 
        x.configuration.application_env_vars.each_pair{|k,v|setenv(k,v)}
        #render facet level env_vars 
        facets.each do | facet |      
          comment nil
          comment "facet #{facet.key.inspect} owner #{facet.owner}"
          facet.render self
        end
      end


      # Low-level rendering.
      
      # Renders a comment if verbose.
      def comment str
        return unless verbose 
        if str
          str = str.to_s.gsub(/\n/, "\n#")
          puts "# #{str}"
        else
          puts ""
        end
      end
      

      def normalize_env_name name
        name = name.to_s.gsub(/[^A-Z0-9_]/i, '_')
      end


      # Render a basic environment variable set.
      def setenv name, val
        name = normalize_env_name name
        name = name.to_s
        val = val.to_s
        if env_var_prefix == ''
          _setenv "CABAR_ENV_#{name}", val
        end
        _setenv "#{env_var_prefix}#{name}", val
      end


      # Renders low-level environment variable set.
      # Subclass should override this.
      def _setenv name, val
        # NOTHING
      end
      
    end # class

    
    # Renders environment variables directly into
    # this Ruby process.
    class InMemory < EnvVar
      def initialize *args
        @env = ENV
        super
      end

      def comment str
        if verbose
          $stderr.puts "# #{$0} #{str}"
        end
      end

      # Note renders RUBYLIB directly into $:.
      def _setenv name, val 
        if verbose
          $stderr.puts "# #{$0} setenv #{name.inspect} #{val.inspect}"
        end
        name = normalize_env_name name
        if (v = @env[name]) && ! @env[save_name = "CABAR_BEFORE_#{name}"]
          @env[save_name] = v
        end
        @env[name] = val

        if name == 'RUBYLIB' && @env.object_id == ENV.object_id
          $:.clear
          $:.push(*Cabar.path_split(val))
          # $stderr.puts "Changed $: => #{$:.inspect}"
        end
      end
    end # class


    # Renders environment variables as a sourceable /bin/sh shell script.
    class ShellScript < EnvVar
      def _setenv name, val 
        name = normalize_env_name name
        puts "#{name}=#{val.inspect}; export #{name};"
      end
    end # class

    
    # Renders environment variables as Ruby code.
    class RubyScript < EnvVar
      def _setenv name, val
        name = normalize_env_name name
        puts "ENV[#{name.inspect}] = #{val.inspect};"
      end
    end # class


  end # class
  
end # module


# TODO: Remove when clients expliclity require this module.
require 'cabar/renderer/yaml'
