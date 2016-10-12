import File, Process from howl.io

aisu.commands = {}

yield = -> select 2, coroutine.yield!

query_info_from_repo = (dir) =>
  aisu_config = loadfile dir / 'aisu.moon'
  status, result = if aisu_config
    pcall aisu_config
  else
    false

  if status
    if type(result) != 'table'
      @warn "aisu.moon returned non-table type #{type result}"
    return result
  else
    msg = if result
      "aisu.moon failed with error: #{result}"
    else
      "repository does not contain aisu.moon"
    msg ..= "; trying init.moon"
    @warn msg
    init = loadfile dir / 'init.moon'
    if init
      status, result = pcall init
      if status
        if type(result.info) != 'table'
          @warn "init.moon returned non-table type"
        else
          return meta: result.info
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
    after @, url, dir, vcs, info if after

show_query = (url, dir, vcs, info) =>
  @force_append '\n'
  meta = info and info.meta
  categories = {'author', 'description', 'license', 'version'}
  for cat in *categories
    @force_append "#{aisu.upper cat}: #{meta and meta[cat] or 'unknown'}\n"

build_package = (build) =>
  return if not build
  if type(build) != 'function'
    @error "Project's build function is actually of type #{type build}"
  else
    @force_append 'Performing build step for package...\n'
    status, err = pcall build, @
    if not status
      @warn "package build step failed with error: #{err}"
      @warn 'package may be left in a broken state!'

install_package = (url, dir, vcs, info) =>
  name = File(url).basename\gsub '%.git$', ''
  if aisu.packages[name]
    @warn 'package is already installed!'
  @force_append '\nPackage information:\n'
  show_query @, url, dir, vcs, info
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
    bundles = howl.app.settings.dir / 'bundles'
    bundles\mkdir! if not bundles.exists
    target = bundles / name
    @force_append "Copying repository to #{target}...\n"
    target\delete_all! if target.exists
    cmd = if jit.os == 'Windows'
      {'xcopy', '/e', '/s', '/y'}
    else
      {'cp', '-R'}
    table.insert cmd, dir
    table.insert cmd, target
    Process.execute cmd
    aisu.packages[name] =
      path: tostring target.path
      vcs: vcs.name
    aisu.save_packages!

    build_package @, info.build if info

    @force_append 'Done!\n'
  else
    @force_append 'Install aborted!\n'

uninstall_package = (package) =>
  info = aisu.packages[package]
  if not info
    @error 'Invalid package name\n'
    return
  pcall File(info.path)\delete_all
  aisu.packages[package] = nil
  aisu.save_packages!
  @force_append 'Done!\n'

update_package = (package) =>
  packages = if package == '*'
    aisu.packages
  else
    info = aisu.packages[package]
    if not info
      @error 'Invalid package name\n'
      return
    require('moon').p info
    {[package]: info}

  for package, pi in pairs packages
    @force_append "Updating #{package}... \n"
    vcs = aisu.get_vcs pi.vcs
    if not vcs
      @error "Package has invalid VCS: #{pi.vcs}"
      continue
    orig_id = vcs\revid(pi.path).stripped
    status, err = pcall vcs\update, pi.path
    @error "updating package: #{err}" if not status
    new_id = vcs\revid(pi.path).stripped
    if orig_id == new_id
      @force_append "No new changes (at commit #{orig_id})\n"
    else
      info = query_info_from_repo @, File pi.path
      build_package @, info.build if info
      @force_append "Updated from commit #{orig_id} to #{new_id}\n"
  @force_append 'Done!\n'

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

aisu.commands.list_hook = =>
  @force_append 'List of all packages:\n\n'
  for name, _ in pairs aisu.packages
    @force_append "#{name}\n"

aisu.commands.uninstall_hook = =>
  message = 'Enter the name of the package to uninstall'
  message ..= ' (press ctrl+space for a list of all installed packages): '
  @force_append message
  @open_prompt true
  package = yield!

  uninstall_package @, package

aisu.commands.update_hook = =>
  message = 'Enter the name of the package to update, or * for all packages'
  message ..= ' (press ctrl+space for a list of all installed packages): '
  @force_append message
  @open_prompt true
  package = yield!

  update_package @, package
