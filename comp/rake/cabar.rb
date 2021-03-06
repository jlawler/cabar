
Cabar::Plugin.new do
module Cabar
    class Facet::Rakefile < Facet::Path
      attr_accessor :rakefiles

      def _normalize_options! opts, new_opts = { }
        new_opts = super
        if Hash === opts and opts.invert[nil] and opts[:path].nil?
          x = opts.invert[nil]
          new_opts[:path] = x.to_s
          new_opts.delete(x)
        end
        new_opts
      end

      def inferred?
        File.exist? File.join(component.base_directory, 'Rakefile')
      end

      # Jer: THIS APPEARS TO BE REDUNDANT/COPY N PASTE CODE
      # please explain why the standard #abs_path method was insufficent?
      # -- kurt 2009/06/16
      # Kurt:  THIS IS COPY AND PASTE CODE.  EXCEPT FOR THE LAST LINE.
      # give the fact that we don't have an easy way to pass a more
      # complicated data structure through env vars, I implemented a 
      # rudimentry (read: ghetto) system for passing key-value pairs.
      # Admittedly, I copied and pasted this code, except for the last line.
      # I saw no easy way to reuse the majority of the code without
      # a significant investment of refactoring time.  This seemed bad
      # because I was guessing there would be other cases we needed
      # to pass key-value pairs around and we would end up standardizing
      # that.
      # -- jwl 2009/07/13
      def abs_path
        @abs_path ||=
        owner &&
        begin
          @abs_path = EMPTY_ARRAY # recursion lock.

          x = path.map { | dir | File.expand_path(expand_string(dir), owner.base_directory) }

          arch_dir = arch_dir_value
          if arch_dir
            # arch_dir = [ arch_dir ] unless Array === arch_dir
            x.map! do | dir |
              if File.directory?(dir_arch = File.join(dir, arch_dir))
                dir = [ dir, dir_arch ]
                # $stderr.puts "  arch_dir: dir = #{dir.inspect}"
              end
              dir
            end
            x.flatten!
            # $stderr.puts "  arch_dir: x = #{x.inspect}"
          end
          #We need to pass not just a path to the rakefile but a component name
          #The way I did this is to make the environment variable contain
          #PATH_TO_COMPONENT!COMPONENT_NAME:
          #So you will end up with /cabar/comp1/Rakefile!comp1:/cabar/comp2/Rakefile!comp2
          @abs_path = x.map{|p|[p,component.name].join('!')}
        end
      end
  end
end

  facet :rakefile, 
      :env_var => :CABAR_RAKE_FILE,
      :std_path => :Rakefile,
      :file_list => true,
      :inferrable => true,
      :class => Cabar::Facet::Rakefile
end

