import Process from howl.io

check_vcs = (vcs) ->
  status, err = pcall Process.run, {vcs, '--version'}
  return status != nil

aisu.read_url = (url, warn = ->) ->
  git = check_vcs 'git'
  hg = check_vcs 'hg'
  assert git or hg,
    'You need to have either Git or Hg (preferably both) installed'
  vcs_list = {:git, :hg}
  for vcs, present in pairs vcs_list
    warn "#{vcs} isn't installed" if not present
  print 123
