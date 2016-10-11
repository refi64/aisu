import Process from howl.io

class Vcs
  new: (@exe) =>

class Git extends Vcs
  new: => super 'git'

class Mercurial extends Vcs
  new: => super 'hg'

try_exec = (args) ->
  status, err = pcall Process.execute, args
  return status

check_vcs = (vcs) -> try_exec {vcs, '--version'}

is_url = (url) -> url\find('://') and true or false

aisu.read_url = (url, note = ->) ->
  git = check_vcs 'git'
  hg = check_vcs 'hg'
  if not git and not hg
    note 'You need to have either Git or Hg (preferably both) installed'
    return
  vcs_list = {Git: git, Mercurial: hg}
  for vcs, present in pairs vcs_list
    note "WARNING: #{vcs} isn't installed" if not present

  if not is_url url
    url = "https://github.com/#{url}"
    note "Not a URL; assuming it's a GitHub repository at #{url}"

  return url
