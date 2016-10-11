aisu.commands = {}

yield = -> select 2, coroutine.yield!

aisu.commands.install_hook = =>
  @force_append 'Enter the name of the package to query: '
  @open_prompt!
  package = yield!

  info = aisu.init_info!
  if not info.git and not info.hg
    @force_append 'You need to have either Git or Hg (preferably both) installed\n'
    return
  for vcs, present in pairs info
    if not present
      @force_append "WARNING: #{vcs} isn't installed\n" if not present

  url = aisu.read_url package
  if package != url
    @force_append "Not a URL; assuming it's a GitHub repository at #{url}\n"

  kind = aisu.identify_repo url
  if not kind
    @force_append 'Invalid repository URL; neither git nor hg could identify it\n'
    return
  else
    @force_append "Identified as a #{kind.name} repo\n"
