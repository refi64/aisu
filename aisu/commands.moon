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
      @warn "aisu.moon returned non-table type #{type result}"
    return result
  else
    @warn "repository does not contain aisu.moon; trying init.moon"
    init = loadfile dir / 'init.moon'
    if init
      status, result = pcall init
      if status
        if type(result.info) != 'table'
          @warn "init.moon returned non-table type"
        else
          return result.info
      else
        @warn "failed to load init.moon: #{result}"
    else
      @warn "could not locate init.moon"
  nil

perform_query = (package, after) =>
  vcs_status = aisu.init_info!
  if not vcs_status.git and not vcs_status.hg
    @error 'You need to have either Git or Hg (preferably both) installed'
    return
  for vcs, present in pairs vcs_status
    if not present
      @warn "#{vcs} isn't installed" if not present

  url = aisu.read_url package
  if package != url
    @force_append "Not a URL; assuming it's a GitHub repository at #{url}\n"

  vcs = aisu.identify_repo url
  if not vcs
    @error 'Invalid repository URL; neither git nor hg could identify it'
    return
  else
    @force_append "Identified as a #{vcs.name} repo\n"

  aisu.with_tmpdir (dir) ->
    @force_append "Cloning repository to #{dir}... "
    vcs\clone url, dir
    @force_append 'done\n'
    @force_append 'Querying information from repository...\n'
    info = query_info_from_repo @, dir
    after @, url, dir, info if after

show_query = (url, dir, info) =>
  @force_append '\n'
  categories = {'author', 'description', 'license', 'version'}
  for cat in *categories
    @force_append "#{aisu.upper cat}: #{info and info[cat] or 'unknown'}\n"

install_package = (url, dir, info) =>
  @force_append '\nPackage information:\n'
  show_query @, url, dir, info
  yn = nil
  while yn == nil
    @force_append '\nDo you wish to install (y/n)? '
    @open_prompt!
    ans = yield!
    if ans == 'y'
      yn = true
    elseif ans == 'n'
      yn = false
    else
      @error "Invalid answer: #{ans}\n"
  if yn
    name = howl.io.File(url).basename\gsub '%.git$', ''
    bundles = howl.app.settings.dir / 'bundles'
    bundles\mkdir! if not bundles.exists
    target = bundles / name
    @force_append "Copying repository to #{target}...\n"
    cmd = if jit.os == 'Windows'
      {'xcopy', '/e', '/s', '/y'}
    else
      {'cp', '-R'}
    table.insert cmd, dir
    table.insert cmd, target
    howl.io.Process.execute cmd
  else
    @force_append 'Install aborted!\n'

aisu.commands.query_hook = =>
  @force_append 'Enter the name of the package to query: '
  @open_prompt!
  package = yield!

  perform_query @, package, show_query

aisu.commands.install_hook = =>
  @force_append 'Enter the name of the package to install: '
  @open_prompt!
  package = yield!

  perform_query @, package, install_package
  @force_append 'Done!'
