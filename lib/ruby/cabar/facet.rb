require 'cabar/base'

require 'pp'

module Cabar

  # A Facet represents the result of slicing off a component
  # from a monolithic software system.
  #
  # Facets are used to compose components in an extendable manner.
  #
  # Examples:
  #   search paths
  #   environment variables
  #   configuration settings
  #   dependencies
  #   build actions
  #   test actions
  #   packaging
  #   deployment
  #   component instantiation
  #   version control
  # 
  class Facet < Base
    # The key for matching a component's configuration against.
    attr_accessor :key

    # The prototype used to create this object.
    attr_accessor :_proto

    # The Plugin that defined this Facet.
    attr_accessor :_defined_in

    # True if the Facet is inferrable.
    attr_accessor :inferrable
    alias :inferrable? :inferrable

    # The owner of the facet, usu. the Component.
    attr_accessor :owner
    alias :component :owner

    # The Loader object.
    attr_accessor :_loader

    # The configuration hash.
    attr_accessor :configuration


    def initialize *args
      @inferrable = false
      super
    end


    @@key_to_proto = { }


    # Returns all the current Facet prototype object.
    def self.prototypes
      @@key_to_proto.values
    end


    # Returns the Facet prototype by its key.
    def self.proto_by_key key
      key = key.to_s
      @@key_to_proto[key]
    end


    # Registers a Facet prototype by its key.
    def self.register_prototype facet_proto, key = nil
      case key
      when Array
        key.map { | t | register_prototype facet_proto, t }
      else
        key ||= facet_proto.key.to_s
        _logger.debug2 do
          "register_prototype(#{facet_proto.inspect}) as #{key.inspect}"
        end
        @@key_to_proto[key] ||= facet_proto
      end
    end


    # Returns true if the Facet is actually inferred.
    def infer?
      result = 
        inferrable? && inferred?

      _logger.debug2 do
        [ 
         "#{key} inferrable? => #{inferrable?.inspect}",
         "#{key} inferred? => #{inferred?.inspect}",
         "#{component.inspect} #{key} infer? result => #{result.inspect}"
        ] 
      end

      result
    end


    # Returns true if Facet is inferred by some component attribute.
    def inferred?
      false
    end


    # Expands String in context of the Facet's Component.
    def expand_string str
      return str unless String === str
      if str =~ /\#\{/
        str = '"' + str.sub(/[\\\"]/){|x| "\\#{x}"} + '"'
        component.instance_eval(str)
      else
        str
      end
    end


    # Unique Array while preserving last-most order
    # instead of preserving first-most order.
    #
    # Example:
    #
    #   [ :a, :b, :a, :c ].uniq => 
    #     [ :a, :b, :c ]
    #
    #   uniq_lastmost([ :a, :b, :a, :c ]) =>
    #     [ :b, :a, :c ]
    #
    # This is useful leave standard search paths
    # towards the end, regardless if they reoccur
    # at the front.
    #
    def uniq_lastmost a
      a && a.reverse.uniq.reverse
    end


    def register_prototype!
      self.class.register_prototype self
      self
    end


    # Creates a new Facet instance by cloning a Facet prototype.
    def self.create proto_name, conf = EMPTY_HASH, opts = EMPTY_HASH
      _logger.debug2 do
        "#{self}.create #{proto_name} #{conf.inspect} #{opts.inspect}"
      end

      # Get the prototype object.
      case proto_name
      when Facet 
        proto = proto_name
      else
        proto = @@key_to_proto[proto_name.to_s]
      end
      
      # Process early?
      if opts[:early] 
        return nil unless proto
        return nil unless proto.configure_early?
      else
        unless proto
          #If you want to not explode on unknown facets
          #return instead of raise here.
          #FIXME make a config option so you can specify
          # "Don't blow up on unknown facets"
          raise Error, "unknown Facet #{proto_name.inspect}"
        end
        return nil if proto.configure_early?
      end

      # Ask prototype to reformat and normalize its configuration options.
      # $stderr.puts "\nconf = #{conf.inspect}"
      conf = proto._reformat_options! conf
      # $stderr.puts "\nconf = #{conf.inspect}"
      conf = proto._normalize_options! conf
      # $stderr.puts "\nconf = #{conf.inspect}"
      return conf unless conf

      # Clone the prototype.
      obj = proto.dup

      # Remember the object's prototype.
      obj._proto = proto

      # Final opts processing by caller.
      yield conf, obj if block_given?

      # Set the clone's configuration.
      obj._options = conf

      obj
    end


    DISABLED_HASH = { :enabled => false }.freeze


    def _reformat_options! opts
      # Handle short-hand options.
      case opts
      when true
        opts = EMPTY_HASH
      when false, nil
        opts = DISABLED_HASH
      end

      opts
    end


    # Ensures key is a String.
    def key= x
      @key = x.to_s
      x
    end


    def to_s
      @key.to_s
    end


#    def <=> f
#      @key <=> f.key
#    end


    # Returns true if the Facet is composable across Components.
    def is_composable?
      true
    end


    # Returns true if the Facet can be configured early.
    def configure_early?
      false
    end


    # Returns true if the Facet is enabled.
    def enabled?
      o = _options
      o[:enabled].nil? || o[:enabled]
    end


    # Called when a Facet is going to be attached
    # to a Component.
    # Subclasses may override this.
    def attach_component! c
      c.attach_facet!(self)
    end

    # Called to compose Facets across Components.
    #
    # For example: module search paths from each Component
    # might be concatenated.
    #
    # Subclasses must override this.
    def compose! facet
      raise "not implemented"
    end


    # Render the Facet with the Renderer.
    #
    # Subclasses may override this.
    def render r
    end


    # Ask the Facet to selected any Components that
    # it constrains.
    #
    # Subclasses may override this.
    def select_component! resolver
    end


    # Ask the Facet to resolve and Components that
    # it may depend on.
    #
    # Subclasses may override this.
    def resolve_component! resolver
    end


    # Ask the Facet to require and any Components that
    # it may depend on.
    #
    # Subclasses may override this.
    def require_component! resolver
    end


    # Called when a component owning this facet
    # has resolved component dependency.
    def component_dependency_resolved! resolver
    end


    # Used for YAML formatting and general inspection.
    #
    # Subclasses may override this.
    def to_a
      [
        [ :class,    self.class.to_s ],
        [ :key,      key ],
        # [ :_options,  _options ],
      ]
    end

  end # class

end # module


