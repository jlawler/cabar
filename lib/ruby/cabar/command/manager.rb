require 'cabar/base'

require 'cabar/error'
require 'cabar/command'


module Cabar
  class Command
    # Manages a list of commands.
    class Manager < Base
      # The owner of this manager.
      attr_accessor :owner

      # A list of all commands.
      attr_reader :commands

      # A Hash that maps command names (and aliases) to Command objects.
      attr_reader :command_by_name
      
      def initialize *args
        @commands = [ ]
        @command_by_name = { }
        super
      end
      
      def command_names
        @command_by_name.keys.sort
      end
      
      def commands
        @commands
      end
      
      def empty?
        @commands.empty?
      end
      
      def deepen_dup!
        super
        @commands = @commands.dup
        @command_by_name = @command_by_name.dup
      end
      
      def register_command! cmd
        # $stderr.puts "#{self.inspect} register_command! #{cmd.name.inspect}"

        return nil if @commands.include? cmd

        @commands << cmd

        (cmd.aliases + [ cmd.name ]).each do | name |
          name = name.to_s
          if @command_by_name[name]
            raise InvalidCommand, "A command named #{name.inspect} is already registered"
          end
          @command_by_name[name] = cmd
          # $stderr.puts "  register_command! #{cmd.inspect} as #{name.inspect}"
        end
        
        cmd
      end
      
      def create_command! name, opts, blk
        opts = { :documentation => opts } unless Hash === opts
        
        opts[:aliases] = EMPTY_ARRAY
        if Array === name
          opts[:aliases] = name[1 .. -1]
          name = name.first
        end
        
        cls = opts[:class] || Command
        opts.delete(:class)
        
        opts[:name] = name.to_s.freeze
        opts[:aliases] = opts[:aliases].map{|x| x.to_s.freeze}.freeze
        opts[:proc] = blk
        opts[:supercommand] = owner if Command === owner        
        
        # $stderr.puts "opts = #{opts.inspect}"
        
        cmd = cls.factory.new opts
        
        cmd
      end
      
      # Define a command.
      def define_command name, opts = nil, &blk
        cmd = create_command! name, opts, blk
        register_command! cmd
        cmd
      end
      alias :cmd :define_command
      
      # Define a command group.
      def define_command_group name, opts = nil, &blk
        opts ||= { }
        cmd = create_command! name, opts, nil
        cmd.instance_eval &blk if block_given?
        cmd.documentation = <<"DOC"
[ #{cmd.subcommands.commands.map{|x| x.name}.sort.join(' | ')} ] ...
* '#{cmd.name_full}' command group.
DOC
        register_command! cmd
        cmd
      end
      alias :cmd_group :define_command_group
      
      
      # Recursively visits commands.
      def visit_commands opts = { }, &blk
        opts[:indent] ||= '    '
        opts[:cmd_path] ||= [ ]
        
        commands.sort { |a, b| a.name <=> b.name }.each do | cmd | 
          opts[:cmd_path].push cmd.name
          
          indent_old = opts[:indent].dup
          
          # yield cmd and opts to the block.
          yield cmd, opts
          
          opts[:indent] << '  '
          
          cmd.subcommands.visit_commands opts, &blk
          
          opts[:indent] = indent_old
          opts[:cmd_path].pop
        end
      end
      
      def inspect
        "#<#{self.class} #{object_id} #{owner} #{commands.map{|x| x.name}.inspect}>"
      end

    end # class

  end # class

end # module
