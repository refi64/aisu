import File, Process from howl.io
parse = require 'moonscript.parse'

aisu.commands = {}

aisu.map_packages = (packages, fn, ...) =>
  all = [package for package in packages\gmatch '%S+']
  if #all == 0
    @writeln 'Aborted.', 'aisu-error'
  for package in *all
    @info "Processing package #{package}" if #all != 1
    fn @, package, ...

read_init = (init) =>
  @info "Attempting to parse #{init}..."
  tree = parse.string init\read '*all'
  if tree
    res = {}
    last = tree[#tree]
    if last[1] == 'table'
      for rkv in *last[2]
        key, value = unpack rkv
        if key[1] == 'key_literal' and key[2] == 'info' and value[1] == 'table'
          -- { info: ... }
          for mkv in *value[2]
            meta, data = unpack mkv
            if meta[1] == 'key_literal' and data[1] == 'string'
              res[meta[2]] = data[3]
    return res if next(res) != nil

  @warn "bundle init file #{init} could not be parsed as MoonScript."
  msg = 'Aisu can try running the file, but it might change your editor as '
  msg ..= 'if the package was already installed!'
  @writeln msg, 'aisu-warning'
  if @ask 'Do you want to try anyway (y/n)? ', 'aisu-warning'
    init_f = loadfile init
    if init_f
      status, result = pcall init_f
      if status
        if type(result.info) != 'table'
          @warn "#{init} returned non-table type"
        else
          return result.info
      else
        @warn "failed to run #{init}: #{result}"
    else
      @warn "failed to load #{init}"
  nil

aisu.query_info_from_repo = (dir) =>
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
    msg ..= "; trying init.moon and init.lua"
    @warn msg
    init_moon = dir/'init.moon'
    init_lua = dir/'init.lua'
    local meta
    if init_moon.exists
      meta = read_init @, init_moon
    elseif init_lua.exists
      meta = read_init @, init_lua
    else
      @warn 'could not locate init.moon or init.lua'
    if meta
      return :meta
    else
      return nil

aisu.perform_query = (package, after) =>
  vcs_status = aisu.vcs_info!
  if not vcs_status.git and not vcs_status.hg
    @error 'You need to have either Git or Hg (preferably both) installed'
    return
  for vcs, present in pairs vcs_status
    if not present
      @warn "#{vcs} isn't installed" if not present

  url = aisu.read_url package
  if package != url
    @info "Not a URL; assuming it's a GitHub repository at #{url}"

  vcs = aisu.identify_repo url
  if not vcs
    @error 'Invalid repository URL; neither git nor hg could identify it'
    return
  else
    @info "Identified as a #{vcs.name} repo"

  aisu.with_tmpdir (dir) ->
    @write "Cloning repository to #{dir}... "
    vcs\clone url, dir
    @writeln 'done'
    @writeln 'Querying information from repository...'
    info = aisu.query_info_from_repo @, dir
    after @, url, dir, vcs, info if after

aisu.show_query = (url, dir, vcs, info) =>
  @writeln!
  meta = info and info.meta
  categories = {'author', 'description', 'license', 'version'}
  for cat in *categories
    @writeln "#{aisu.upper cat}: #{meta and meta[cat] or 'unknown'}"

aisu.build_package = (build) =>
  return if not build
  if type(build) != 'function'
    @error "Project's build function is actually of type #{type build}"
  else
    @writeln 'Performing build step for package...'
    status, err = pcall build, @
    if not status
      @warn "package build step failed with error: #{err}"
      @warn 'package may be left in a broken state!'

aisu.install_package = (url, dir, vcs, info) =>
  name = File(url).basename\gsub '%.git$', ''
  if aisu.packages[name]
    @warn 'package is already installed!'
  @writeln!
  @writeln 'Package information:', 'aisu-header'
  aisu.show_query @, url, dir, vcs, info

  if @ask 'Do Do you wish to install (y/n)? '
    bundles = howl.app.settings.dir / 'bundles'
    bundles\mkdir! if not bundles.exists
    target = bundles / name
    @writeln "Copying repository to #{target}..."
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

    aisu.build_package @, info.build if info

    @info 'Done!'
  else
    @writeln 'Install aborted!', 'aisu-error'

aisu.uninstall_package = (package) =>
  info = aisu.packages[package]
  if not info
    @error 'Invalid package name'
    return
  pcall File(info.path)\delete_all
  aisu.packages[package] = nil
  aisu.save_packages!
  @info 'Done!'

aisu.update_package = (package) =>
  packages = if package == '*'
    aisu.packages
  else
    info = aisu.packages[package]
    if not info
      @error 'Invalid package name'
      return
    {[package]: info}

  for package, pi in pairs packages
    @writeln "Updating #{package}..."
    vcs = aisu.get_vcs pi.vcs
    if not vcs
      @error "Package has invalid VCS: #{pi.vcs}"
      continue
    orig_id = vcs\revid(pi.path).stripped
    status, err = pcall vcs\update, pi.path
    @error "updating package: #{err}" if not status
    new_id = vcs\revid(pi.path).stripped
    if orig_id == new_id
      @info "No new changes (at commit #{orig_id})"
    else
      info = aisu.query_info_from_repo @, File pi.path
      aisu.build_package @, info.build if info
      @info "Updated from commit #{orig_id} to #{new_id}"
  @info 'Done!'

aisu.commands.query_hook = =>
  @write 'Enter the path/repo of the package to query: '
  @open_prompt!
  packages = aisu.yield!

  aisu.map_packages @, packages, aisu.perform_query, aisu.show_query

aisu.commands.install_hook = =>
  @write 'Enter the path/repo of the package to install: '
  @open_prompt!
  packages = aisu.yield!

  aisu.map_packages @, packages, aisu.perform_query, aisu.install_package

aisu.commands.list_hook = =>
  @writeln 'List of all packages:', 'aisu-header'
  @writeln!
  for name, _ in pairs aisu.packages
    @writeln "#{name}"

aisu.commands.uninstall_hook = =>
  message = 'Enter the name of the package to uninstall'
  message ..= ' (press ctrl+space for a list of all installed packages): '
  @write message
  @open_prompt!
  packages = aisu.yield!

  aisu.map_packages @, packages, aisu.uninstall_package

aisu.commands.update_hook = =>
  message = 'Enter the name of the package to update, or * for all packages'
  message ..= ' (press ctrl+space for a list of all installed packages): '
  @write message
  @open_prompt!
  packages = aisu.yield!

  aisu.map_packages @, packages, aisu.update_package
