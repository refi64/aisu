import register from howl.command

_G.aisu = {}

aisu.packages_file = howl.app.settings.dir / 'aisu.lua'
aisu.packages = {}

aisu.setup = ->
  unless aisu.packages_file.exists
    aisu.packages_file\open 'w', (fh) -> fh\write 'return {}'
  aisu.packages = dofile aisu.packages_file.path

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

control_buffer = (hook) ->
  buf = aisu.ControlBuffer hook
  editor = howl.app\add_buffer buf
  editor.cursor\eof!

register
  name: 'aisu-query'
  description: 'Query information about a package'
  handler: aisu.bind control_buffer, aisu.commands.query_hook
