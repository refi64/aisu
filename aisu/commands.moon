aisu.commands = {}

yield = -> select 2, coroutine.yield!

query_info_from_repo = (dir) =>
  aisu_config = loadfile dir / 'aisu.moon'
  if aisu_config
    status, result = pcall aisu_config
  else
    status = false

  if status
    if type(result) != 'table'
      @force_append "WARNING: aisu.moon returned non-table type #{type result}\n"
    return result
  else
    @force_append "WARNING: repository does not contain aisu.moon; trying init.moon\n"
    init = loadfile dir / 'init.moon'
    if init
      status, result = pcall init
      if status
        if type(result.info) != 'table'
          @force_append "WARNING: init.moon returned non-table type\n"
        else
          return result.info
      else
        @force_append "WARNING: failed to load init.moon: #{result}\n"
    else
      @force_append "WARNING: could not locate init.moon\n"
  nil

aisu.commands.query_hook = =>
  @force_append 'Enter the name of the package to query: '
  @open_prompt!
  package = yield!

  vcs_status = aisu.init_info!
  if not vcs_status.git and not vcs_status.hg
    @force_append 'You need to have either Git or Hg (preferably both) installed\n'
    return
  for vcs, present in pairs vcs_status
    if not present
      @force_append "WARNING: #{vcs} isn't installed\n" if not present

  url = aisu.read_url package
  if package != url
    @force_append "Not a URL; assuming it's a GitHub repository at #{url}\n"

  vcs = aisu.identify_repo url
  if not vcs
    @force_append 'Invalid repository URL; neither git nor hg could identify it\n'
    return
  else
    @force_append "Identified as a #{vcs.name} repo\n"

  aisu.with_tmpdir (dir) ->
    @force_append "Cloning repository to #{dir}... "
    vcs\clone url, dir
    @force_append 'done\n'
    @force_append 'Querying information from repository...\n'
    info = query_info_from_repo @, dir

    @force_append '\n'
    categories = {'author', 'description', 'license', 'version'}
    for cat in *categories
      @force_append "#{aisu.upper_first cat}: #{info and info[cat] or 'unknown'}\n"
