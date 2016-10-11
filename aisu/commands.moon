aisu.commands = {}

yield = -> select 2, coroutine.yield!

aisu.commands.install_hook = =>
  @force_append 'Enter the name of the package to query: '
  @open_prompt!
  package = yield!
  aisu.read_url package, (msg) -> @force_append "WARNING: #{msg}"
