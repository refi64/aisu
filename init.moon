bundle_load 'aisu.core'

aisu.setup!

unload = ->

{
  info:
    author: 'Ryan Gonzalez'
    description: 'A package manager for Howl'
    license: 'MIT'
  :unload
}
