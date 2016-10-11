import Process from howl.io

class Git
  name: 'git'

class Mercurial
  name: 'hg'

try_exec = (args) ->
  status, stdout, stderr, p = pcall Process.execute, args
  return status and p.successful

check_vcs = (vcs) -> try_exec {vcs, '--version'}

is_url = (url) -> url\find('://') and true or false

aisu.init_info = (note = ->) ->
  git = check_vcs('git') or false
  hg = check_vcs('hg') or false
  return {:git, :hg}

aisu.read_url = (url, note = ->) ->
  return is_url(url) and url or "https://github.com/#{url}.git"

aisu.identify_repo = (url) ->
  if try_exec {'git', 'ls-remote', url}
    return Git
  elseif try_exec {'hg', 'identify', url}
    return Mercurial
