import highlight from howl.ui
import app, mode, Buffer from howl
moon = require 'moon'

class ControlCompleter
  complete: (context) =>
    candidates = {}
    for name, _ in pairs aisu.packages
      table.insert candidates, name

    compls = howl.util.Matcher(candidates) context.word_prefix
    compls.authoritive = true
    compls

ControlMode =
  default_config:
    cursor_line_highlighted: false
    line_wrapping: 'character'
    complete: 'manual'

  keymap: {}

  completers: { ControlCompleter, 'in_buffer' }

with highlight
  .define 'aisu-error',
    type: .ROUNDED_RECTANGLE
    background: 'red'
    background_alpha: 0.5

  .define 'aisu-warning',
    type: .ROUNDED_RECTANGLE
    background: 'purple'
    background_alpha: 0.5

  .define 'aisu-prompt',
    type: .ROUNDED_RECTANGLE
    background: 'gray'
    background_alpha: 0.5

  .define 'aisu-header',
    type: .ROUNDED_RECTANGLE
    background: '#043927'
    background_alpha: 0.5

  .define 'aisu-info'
    type: .ROUNDED_RECTANGLE
    background: '#7ec0ee'
    background_alpha: 0.5

class ControlBuffer extends Buffer
  new: (hook) =>
    super {}
    @hook = @safe_coroutine hook
    @read_only = true
    @title = 'Aisu'
    @mode = mode.by_name 'aisu-control'
    @allow_appends = false
    @prompt_begins = nil

    @_buffer.insert = aisu.bind @\_aullar_override, @_buffer\insert
    @_buffer.delete = aisu.bind @\_aullar_override, @_buffer\delete

    @writeln 'Aisu Console', 'aisu-header'
    @resume!

    -- Workaround for https://github.com/howl-editor/howl/issues/363
    meta = getmetatable @
    meta.__properties = moon.copy Buffer.__properties
    meta.__properties.modified =
      get: -> false
      set: ->

  -- https://github.com/howl-editor/howl/issues/363
  -- @property modified:
    -- get: -> false
    -- set: ->

  _aullar_override: (orig_func, buf, offset, ...) =>
    return if not @allow_appends
    if @prompt_begins
      return unless offset > @prompt_begins
    buf.read_only = false
    status, err = pcall orig_func, offset, ...
    buf.read_only = true
    if status
      @update_prompt!
    else
      error err

  open_prompt: =>
    @allow_appends = true
    @prompt_begins = @length
    @mode.keymap.enter = @\close_prompt
    @update_prompt!

  update_prompt: =>
    return unless @prompt_begins
    highlight.remove_all 'aisu-prompt', @
    highlight.apply 'aisu-prompt', @, @prompt_begins, @length-@prompt_begins+1

  close_prompt: =>
    return if not @prompt_begins
    @allow_appends = false
    text = @sub @prompt_begins+1
    @prompt_begins = nil
    @writeln!
    @mode.config.complete = 'manual'
    @resume text.stripped

  resume: (...) =>
    if coroutine.status(@hook) != 'dead'
      @call coroutine.resume, @hook, @, ...

  call: (f, ...) =>
    errfunc = (err) ->
      @writeln "FATAL ERROR: #{err}", 'aisu-error'
      @writeln debug.traceback!, 'aisu-error'
    status, err = xpcall f, errfunc, ...
    error err if not status

  safe_coroutine: (f) => coroutine.create (...) -> @call f, ...

  _force_append: (...) =>
    allow_appends = @allow_appends
    @allow_appends = true
    result, err = pcall @append, @, ...
    @allow_appends = allow_appends
    app.editor.cursor\eof!
    error err unless result

  write: (text, flair) =>
    pos = @length
    pos = 1 if pos == 0
    @_force_append text
    highlight.apply flair, @, pos, @length - pos if flair

  writeln: (text, flair) => @write "#{text or ''}\n", flair
  info: (text) => @writeln text, 'aisu-info'
  warn: (text) => @writeln "WARNING: #{text}", 'aisu-warning'
  error: (text) => @writeln "ERROR: #{text}", 'aisu-error'

  ask: (text, flair) =>
    yn = nil
    while yn == nil
      @write text, flair
      @open_prompt!
      ans = aisu.yield!
      if ans == 'y'
        yn = true
      elseif ans == 'n'
        yn = false
      else
        @error "Invalid answer: #{ans}"
    return yn

aisu.ControlBuffer = ControlBuffer
mode.register
  name: 'aisu-control'
  create: -> ControlMode
