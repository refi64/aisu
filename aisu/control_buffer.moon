import mode, Buffer from howl

ControlMode =
  default_config:
    cursor_line_highlighted: false
    line_wrapping: 'none'
    complete: 'manual'

  keymap: {}

class ControlBuffer extends Buffer
  new: (hook) =>
    super {}
    @hook = coroutine.create (...) -> @call hook, ...
    @read_only = true
    @title = 'Aisu'
    @mode = mode.by_name 'aisu-control'
    @allow_appends = false
    @prompt_begins = nil

    @_buffer.insert = aisu.bind @\_insert_override, @_buffer\insert

    @force_append 'Aisu Console\n'
    @resume!

  @property modified:
    get: -> false
    set: ->

  _insert_override: (orig_insert, buf, offset, ...) =>
    return if not @allow_appends
    if @prompt_begins
      return unless offset > @prompt_begins
    buf.read_only = false
    status, err = pcall orig_insert, offset, ...
    buf.read_only = true
    error err unless status

  open_prompt: =>
    @allow_appends = true
    @prompt_begins = @length
    @mode.keymap.enter = @\close_prompt

  close_prompt: =>
    return if not @prompt_begins
    @allow_appends = false
    text = @sub @prompt_begins+1
    @prompt_begins = nil
    @force_append '\n'
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
    error err unless result

aisu.ControlBuffer = ControlBuffer
mode.register
  name: 'aisu-control'
  create: -> ControlMode
