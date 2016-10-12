import Process from howl.io

class Vcs
  clone: (url, dir) => Process.execute {@name, 'clone', url, dir}
  exec: (cmd, dir) => Process.execute cmd, { working_directory: dir }

class Git extends Vcs
  name: 'git'
  update: (dir) => @exec {'git', 'pull'}, dir
  revid: (dir) => @exec {'git', 'rev-parse', 'HEAD'}, dir

class Mercurial extends Vcs
  name: 'hg'
  update: (dir) => @exec {'hg', 'pull', '-u'}, dir
  revid: (dir) => @exec {'hg', 'id', '-i'}, dir

aisu.Vcs = Vcs
aisu.Git = Git
aisu.Mercurial = Mercurial

try_exec = (args) ->
  status, stdout, stderr, p = pcall Process.execute, args
  return status and p.successful

aisu.get_vcs = (vcs) ->
  vcslist =
    git: Git
    hg: Mercurial
  vcslist[vcs]

check_vcs = (vcs) -> try_exec {vcs, '--version'}

is_github_repo = (url) -> url\match'^[^/]+/[^/]+$' and true or false

aisu.vcs_info = ->
  git = check_vcs('git') or false
  hg = check_vcs('hg') or false
  return {:git, :hg}

aisu.read_url = (url) ->
  return is_github_repo(url) and "https://github.com/#{url}.git" or url

aisu.identify_repo = (url) ->
  if try_exec {'git', 'ls-remote', url}
    return Git
  elseif try_exec {'hg', 'identify', url}
    return Mercurial
