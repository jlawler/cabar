

Cabar::Plugin.new :name => 'cabar/action' do

  require 'cabar/command/standard' # Standard command support.
  require 'cabar/facet/standard'   # Standard facets and support.

  ##################################################################
  # action facet
  #

  facet :action, :class => Cabar::Facet::Action
  cmd_group :action do

    cmd :list, <<'DOC' do
[ <action> ] 
List actions available on all components.

Actions are commands that can be run on a component:

Defined by:

  facet:
    action:
      name_1: cmd_1
      name_2: cmd_2

DOC
      selection.select_available = true
      selection.to_a

      action = cmd_args.shift

      print_header :component
      get_actions(action).each do | c, facet |
        # puts "f = #{f.to_a.inspect}"
        puts "    #{c.to_s(:short)}: "
        puts "      action:"
        facet.action.each do | k, v |
          next if action && ! (action === k)
          puts "        #{k}: #{v.inspect}"
        end
      end
    end # cmd

    cmd [ :run, :exec, 'do' ], <<'DOC' do
[ --dry-run ] <action> <args> ...
Executes an action on all required components.
DOC
      selection.select_required = true
      selection.to_a

      action = cmd_args.shift || raise(ArgumentError, "expected action name")
      # puts "comp = #{comp}"
       
      # Render environment vars.
      setup_environment!
      # puts ENV['RUBYLIB']

      get_actions(action).each do | c, f |
        f.execute_action! action, cmd_args.dup, cmd_opts
      end

    end # cmd

    class Cabar::Command
      def get_actions action = nil
        actions = [ ]
        
        # puts "selection = #{selection.to_a.inspect}"
        selection.to_a.each do | c |
          # puts "c.facets = #{c.facets.inspect}"
          c.facets.each do | f |
            if f.key == 'action' &&
              (! action || f.can_do_action?(action))
              actions << [ c, f ]
            end
          end
        end
        
        actions
      end

    end # cmd

  end # cmd_group

end # plugin


