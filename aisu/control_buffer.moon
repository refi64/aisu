import highlight from howl.ui
import app, mode, Buffer from howl

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

    @highlighted 'aisu-header', 'Aisu Console\n'
    @resume!

  @property modified:
    get: -> false
    set: ->

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

  open_prompt: (complete) =>
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
    @force_append '\n'
    @mode.config.complete = 'manual'
    @resume text.stripped

  resume: (...) =>
    if coroutine.status(@hook) != 'dead'
      @call coroutine.resume, @hook, @, ...

  call: (f, ...) =>
    errfunc = (err) ->
      @force_append "FATAL ERROR: #{err}\n"
      @force_append debug.traceback!
    status, err = xpcall f, errfunc, ...
    error err if not status

  safe_coroutine: (f) => coroutine.create (...) -> @call f, ...

  force_append: (...) =>
    allow_appends = @allow_appends
    @allow_appends = true
    result, err = pcall @append, @, ...
    @allow_appends = allow_appends
    app.editor.cursor\eof!
    error err unless result

  highlighted: (flair, text) =>
    pos = @length
    pos = 1 if pos == 0
    @force_append text
    highlight.apply flair, @, pos, @length - pos

  warn: (text) => @highlighted 'aisu-warning', "WARNING: #{text}\n"
  error: (text) => @highlighted 'aisu-error', "ERROR: #{text}\n"

aisu.ControlBuffer = ControlBuffer
mode.register
  name: 'aisu-control'
  create: -> ControlMode
