require 'cabar'
require 'cabar/base'

require 'cabar/array'
require 'cabar/error'
require 'cabar/hash'
require 'cabar/version'


module Cabar
  # Provides a run-time interface to the environment generated by Cabar.
  class RunTime < Base
    # Defaults to ENV
    attr_accessor :_env

    attr_reader :component_by_name

    def self.current
      @@current ||= RunTime.factory.new
    end
    def self.current= x
      @@current = x
    end

    def inspect
      to_s
    end

    def initialize opts = EMPTY_HASH
      @component_by_name = { }
      super
      @_env ||= Hash[*ENV.to_a.flatten]
    end

    
    def facets
      @facets ||=
        Facet.parse_facets _env
    end


    # Returns a component by name.
    def component name
      name = name.to_s
      required_components
      @component_by_name[name] || 
        raise(Cabar::Error, "Cannot find component named #{name.inspect}")
    end


    # Returns all the required components for the current environment.
    def required_components
      @required_components ||= 
        begin
          @required_components = [ ]
          _env['CABAR_REQUIRED_COMPONENTS'].split(/\s+/).each do | c_name |
            c = 
            @component_by_name[c_name] ||= 
            Component.factory.
            new(:_run_time => self, :name => c_name).
            initialize_from_env_var!

            @required_components << c
          end
          @required_components
        end
    end


    # Returns all the top-level component.
    def top_level_components
      @top_level_components ||=
        begin
          required_components

          @top_level_components = [ ]
          _env['CABAR_TOP_LEVEL_COMPONENTS'].split(/\s+/).each do | c_name |
            c = 
            @component_by_name[c_name] || 
            (raise Cabar::Error, "Cannot find component #{c_name.inspect}")

            @top_level_components << c
          end
          @top_level_components
        end
    end


    class Facet < Base
      attr_accessor :_run_time
      attr_accessor :_proto
      attr_accessor :owner
      attr_accessor :key, :env_var
      attr_accessor :value, :path
      
      def to_s
        @to_s ||=
          "#<#{self.class} #{key} #{env_var} #{@value && @value.inspect}>"
      end

      def inspect
        to_s
      end

      def self.parse_facets _env
        # $stderr.puts "_env = #{_env.inspect}"

        facet_key_env_var = 
          (_env['CABAR_FACET_ENV_VAR_MAP'] || '').
          split(',').
          map { | x | x.split('=', 2) }
        facet_key_env_var = Hash[*facet_key_env_var.flatten]

        (_env['CABAR_FACETS'] || '').
          split(',').map do | key |
          env_var = facet_key_env_var[key]
          Facet.new(:key => key, 
                    :env_var => env_var,
                    :value => _env[env_var]
                    )
        end
      end

      def _env
        _run_time._env
      end

      def initialize opts = { }
        super
        if owner && env_var
          @value = _env["CABAR_#{owner.var_name}_#{env_var}"]
        end
      end

      def value
        @value ||= _env[env_var]
      end

      def path
        @path ||= 
          value.split(Cabar.path_sep).freeze
      end
    end


    # Simple lightweight standin for Cabar::Component.
    class Component < Base
      attr_accessor :_run_time
      attr_accessor :name
      attr_accessor_type :version, Cabar::Version
      attr_accessor :component_type
      attr_accessor :directory
      attr_accessor :base_directory

      def to_s
        @to_s ||=
          "#{name}/#{version}@#{directory}"
      end

      def inspect
        to_s
      end

      def _env
        _run_time._env
      end

      def _var_name
        @var_name ||= 
          @name.gsub(/[^a-z_0-9]/i, '_').freeze
      end

      def initialize_from_env_var!
        # $stderr.puts "  #{name.inspect} => #{_var_name.inspect}"
        self.version = _env["CABAR_#{_var_name}_VERSION"].dup.freeze
        self.directory = _env["CABAR_#{_var_name}_DIRECTORY"].dup.freeze
        self.base_directory = _env["CABAR_#{_var_name}_BASE_DIRECTORY"].dup.freeze
        self
      end

      def facets
        @facets ||=
          begin
            @facets = [ ]
            _run_time.facets.each do | pf |
              next unless pf.env_var
              if v = _env["CABAR_#{_var_name}_#{pf.env_var}"]
                f = pf.dup
                f._proto = pf
                f._run_time = _run_time
                f.owner = self
                f.value = v.dup.freeze
                f.path = nil # flush cache
                @facets << f
              end
          end
            @facets
          end
      end # facets

      def facet_by_key
        @facet_by_key ||=
          facets.inject({ }) { | h, f | h[f.key] = f; h }
      end

      def facet key
        key = key.key if Facet === key 
        facet_by_key[key.to_s]
      end

    end # class
    
  end # class


end # module

