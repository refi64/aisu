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

class ControlBuffer extends Buffer
  new: (hook) =>
    super {}
    @hook = coroutine.create (...) -> @call hook, ...
    @read_only = true
    @title = 'Aisu'
    @mode = mode.by_name 'aisu-control'
    @allow_appends = false
    @prompt_begins = nil

    @_buffer.insert = aisu.bind @\_aullar_override, @_buffer\insert
    @_buffer.delete = aisu.bind @\_aullar_override, @_buffer\delete

    @force_append 'Aisu Console\n'
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
    error err unless status

  open_prompt: (complete) =>
    @allow_appends = true
    @prompt_begins = @length
    @mode.keymap.enter = @\close_prompt

  close_prompt: =>
    return if not @prompt_begins
    @allow_appends = false
    text = @sub @prompt_begins+1
    @prompt_begins = nil
    @force_append '\n'
    @mode.config.complete = 'manual'
    @resume text

  resume: (...) =>
    if coroutine.status(@hook) != 'dead'
      @call coroutine.resume, @hook, @, ...

  call: (f, ...) =>
    errfunc = (err) ->
      print err
      @force_append "FATAL ERROR: #{err}\n"
      @force_append debug.traceback!
    status, err = xpcall f, errfunc, ...
    error err if not status

  force_append: (...) =>
    allow_appends = @allow_appends
    @allow_appends = true
    result, err = pcall @append, @, ...
    @allow_appends = allow_appends
    app.editor.cursor\eof!
    error err unless result

  warn: (text) => @force_append "WARNING: #{text}\n"
  error: (text) => @force_append "ERROR: #{text}\n"

aisu.ControlBuffer = ControlBuffer
mode.register
  name: 'aisu-control'
  create: -> ControlMode
