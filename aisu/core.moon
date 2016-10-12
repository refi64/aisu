import register from howl.command

_G.aisu = {}

aisu.packages_file = howl.app.settings.dir / 'aisu.lua'
aisu.packages = {}

aisu.setup = ->
  unless aisu.packages_file.exists
    aisu.packages_file\open 'w', (fh) -> fh\write 'return {}\n'
  status, result = pcall dofile, aisu.packages_file.path
  aisu.packages = status and result or {}

aisu.save_packages = ->
  aisu.packages_file\open 'w', (fh) ->
    write_k = (k) -> fh\write "['#{k}'] = "

    fh\write 'return {\n'
    for name, info in pairs aisu.packages
      fh\write "  ['#{name}'] = {\n"
      for k, v in pairs info
        fh\write "    ['#{k}'] = '#{v}',\n"
      fh\write '  },\n'
    fh\write '}\n'

bundle_load 'aisu.control_buffer'
bundle_load 'aisu.commands'
bundle_load 'aisu.vcs'

aisu.bind = (f, ...) ->
  args = {...}
  (...) -> f unpack(args), ...

aisu.with_tmpdir = (f) ->
  dir = howl.io.File.tmpdir!
  status, err = pcall f, dir
  pcall dir\delete_all
  error err if not status

aisu.upper = (s) -> s\gsub '^%l', string.upper

aisu.spawn_in_buffer = (buf, args) ->
  add = (data) -> buf\force_append data or ''
  args.read_stdout = true
  args.read_stderr = true
  p = howl.io.Process args
  buf\highlighted 'aisu-header', "Running process '#{p.command_line}'\n"
  p\pump add, add
  p

control_buffer = (hook) ->
  buf = aisu.ControlBuffer hook
  editor = howl.app\add_buffer buf
  editor.cursor\eof!

register
  name: 'aisu-query'
  description: 'Query information about a package'
  handler: aisu.bind control_buffer, aisu.commands.query_hook

register
  name: 'aisu-install'
  description: 'Install a package'
  handler: aisu.bind control_buffer, aisu.commands.install_hook

register
  name: 'aisu-list'
  description: 'List all installed packages'
  handler: aisu.bind control_buffer, aisu.commands.list_hook

register
  name: 'aisu-uninstall'
  description: 'Uninstall a package'
  handler: aisu.bind control_buffer, aisu.commands.uninstall_hook

register
  name: 'aisu-update'
  description: 'Update your packages'
  handler: aisu.bind control_buffer, aisu.commands.update_hook
