

Cabar::Plugin.new :name => 'cabar/env', :documentation => <<'DOC' do
Environment variable support.
DOC

  require 'cabar/command/standard' # Standard command support.
  require 'cabar/facet/standard'   # Standard facets and support.

  ##################################################################
  # env facet
  #

  facet :env,     :class => Cabar::Facet::EnvVarGroup
  cmd :env, <<'DOC' do
[ - <component> ]
Lists the environment variables for a selected component
as a sourceable /bin/sh script.
DOC

    select_root cmd_args
    
    r = Cabar::Renderer::ShellScript.new cmd_opts
    
    context.render r
  end # cmd

end # plugin

