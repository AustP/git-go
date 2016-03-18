{exec, spawn} = require 'child_process'
path = require 'path'

module.exports =
  child: null
  cwd: null
  history: []
  history_index: 0
  tabs: 0

  escapeHTML: (raw) ->
    map =
      '&': '&amp;'
      '<': '&lt;'
      '>': '&gt;'
      '"': '&quot;'
      "'": '&#039;'
    raw.replace /[&<>"']/g, (m) -> map[m]

  addOutput: (message) ->
    output = @output[0]
    has_new_line = output.innerHTML.length is 0 or output.innerHTML[output.innerHTML.length-1] is "\n"

    output.innerHTML += (if has_new_line then '' else "\n") + @escapeHTML(message.trim())
    output.scrollTop = output.scrollHeight

  clearInputText: ->
    @input.setText if @child? then '' else "#{@cwd}$ "

  getCommand: ->
    input_text = @input.getText()
    string = input_text.substr(@cwd.length + 2)
    string = input_text if string is '' and input_text.indexOf(@cwd) is -1
    raw_args = string.split(' ')

    # handle quotes
    args = []
    for value, i in raw_args
      continue if i <= j
      if value[0] is '"' or value[0] is "'"
        quote = value[0]
        value = value.substr(1)
        if value[value.length-1] isnt quote
          for j in [i+1...raw_args.length]
            next = raw_args[j]
            if next[next.length-1] is quote
              value += " #{next.substr(0, next.length-1)}"
              break
            else
              value += " #{next}"
        else
          value = value.substr(0, value.length-1)
      args.push value

    quoted_args = args

    # stitch together args with escaped spaces
    skip = false
    args = []
    arg = ''
    for raw_arg, i in quoted_args
      if raw_arg[raw_arg.length-1] is '\\' and i+1 isnt quoted_args.length
        if arg and arg[arg.length-1] is '\\'
          arg = "#{arg.substr(0, arg.length-1)} "

        arg += "#{raw_arg.substr(0, raw_arg.length-1)} "
        skip = true
      else
        arg += raw_arg

      if !skip
        args.push arg
        arg = ''

      skip = false

    if arg
      args.push arg

    # TODO: handle && and ||
    # for arg in args
    #   if arg is '&&'
    #   else if arg is '||'

    string: string
    file: args[0]
    args: args.splice(1)

  addHistory: (command) ->
    @history.push command unless @history.slice(-1)[0] is command
    @history_index = @history.length

  handleClear: ->
    @output[0].innerHTML = ''
    @addOutput "#{@cwd}$ "
    @clearInputText()

  handleCD: (command) ->
    return @clearInputText() unless command.args[0]

    command.args[0] = @env.HOME if command.args[0] is '~'

    cwd = path.resolve @cwd, command.args[0]
    @exec "cd #{cwd}", (error, stdout, stderr) =>
      if !error? and !stderr
        @cwd = cwd
      @clearInputText()

  closeChild: ->
    return unless @child
    @child.disconnect() if @child.connected
    @child = null
    @clearInputText()

  exec: (command, cb = ->) ->
    exec command, {cwd: @cwd, env: @env}, (error, stdout, stderr) =>
      if error?
        message = error.message.split("\n").splice(1).join("\n")
        @addOutput message
      else
        @addOutput stdout if stdout
        @addOutput stderr if stderr
      cb error, stdout, stderr
      @closeChild()

  loadHistory: ->
    return if @child?
    @clearInputText()
    history = @history[@history_index] or ''
    @input.setText "#{@input.getText()}#{history}"

  displayIntroduction: ->
    html = """
      git-go terminal - <a href="http://github.com/austp/git-go">http://github.com/austp/git-go</a>
      If you have suggestions of commonly used git commands, please open an issue on the github page.
      ** In order to use the tab functionality of the git-go terminal, ls must be available from your command line.
      ** For Windows users: instructions for adding ls to your command line can be found on the github page.

      If you don't want to see this introduction again, you can hide it from the settings page.
    """
    @output[0].innerHTML = html

  setForceKillShortcut: (shortcut) ->
    @force_kill_shortcut = shortcut

  setAskpassPath: (path) ->
    @env.SUDO_ASKPASS = path if path

  initialize: (@output, @input) ->
    if atom.config.get 'git-go.displayIntroduction'
      @displayIntroduction()
    else
      @output[0].innerHTML = "git-go terminal - <a href='http://github.com/austp/git-go'>http://github.com/austp/git-go</a>"

    @input.on 'keydown', (e) => @inputKeydownHandler(e)
    @input.on 'keyup', (e) => @inputKeyupHandler(e)

    @cwd = atom.project.getPaths()[0]
    @env = process.env
    @clearInputText()

    @

  inputKeydownHandler: (e) ->
    switch
      when e.which is 9 then e.preventDefault()
      when e.which is 27 and @force_kill_shortcut is 'Escape' then @forceKill()
      when e.which is 36 then @cursor_column = @input.model.getCursorBufferPosition().column
      when e.which is 67 and e.ctrlKey then @ctrlCHandler()
      when e.which is 88 and e.ctrlKey and @force_kill_shortcut is 'Ctrl-X' then @forceKill()
      when e.which is 90 and e.ctrlKey and @force_kill_shortcut is 'Ctrl-Z' then @forceKill()
      else null

  inputKeyupHandler: (e) ->
    @tabs = 0 if e.which isnt 9
    switch
      when e.which is 9 then @tabHandler()
      when e.which is 13 then @enterHandler()
      when e.which is 36 then (=>
        if e.shiftKey
          @input.model.setSelectedBufferRange([[0, @cwd.length+2], [0, @cursor_column]])
        else
          @input.model.setCursorBufferPosition([0, @cwd.length+2])
      )()
      when e.which is 38 then @upHandler()
      when e.which is 40 then @downHandler()
      when @input.getText().indexOf("#{@cwd}$ ") isnt 0 and !@child? then @clearInputText()
      else null

  escapeArgs: (command, substr) ->
    substr = substr.replace /([^\\]) /g, '$1\\ '
    string = path.normalize command.string
    string = string.substr 0, string.lastIndexOf substr
    string += command.args[command.args.length-1].replace /([^\\]) /g, '$1\\ '

  tabHandler: ->
    command = @getCommand()
    arg = command.args.splice(-1)[0]
    arg = command.file unless arg

    arg = path.normalize arg

    substr = null
    if arg[arg.length-1] isnt path.sep
      parts = arg.split path.sep
      substr = parts.splice(-1)[0]
      arg = "#{parts.join(path.sep)}#{if parts.length then path.sep else ''}"

    @tabs++

    all_flag = if substr and substr[0] is '.' then '-a' else '-A'

    exec "ls #{all_flag} --file-type \"#{path.resolve(@cwd, arg)}\"", {env: @env}, (error, stdout, stderr) =>
      outcomes = stdout.split "\n"
      return unless outcomes.length

      if substr?
        results = []
        for outcome in outcomes
          results.push(outcome) if outcome.indexOf(substr) is 0
        outcomes = results

      return unless outcomes.length

      if outcomes.length is 1
        if outcomes[0][outcomes[0].length-1] is "/"
          outcome = outcomes[0].substr(0, outcomes[0].length-1)
          outcome += path.sep if outcome and outcome.indexOf(' ') is -1
        else
          outcome = outcomes[0]

        if arg and arg[arg.length-2] is '"' and arg[arg.length-1] is path.sep
          arg = "#{arg.substr(0, arg.length-2)}#{path.sep}"

        command.args.push "#{arg}#{outcome}"
        @input.setText "#{@cwd}$ #{@escapeArgs(command, arg + substr)}"
        @tabs = 0
      else
        if outcomes.length and substr
          original_substr = substr
          i = substr.length
          substr = ''

          running = true
          while running
            char = ''
            for outcome, l in outcomes
              if l is 0
                char = outcome[i]

                if !char
                  running = false
                  break

                continue

              if outcome[i] isnt char
                running = false
                break

            if running
              substr += char
              i++

          if substr
            command.args.push "#{arg}#{original_substr}#{substr}"
            @input.setText "#{@cwd}$ #{@escapeArgs(command, arg + original_substr)}"

        if @tabs > 1
          @addOutput "#{@cwd}$ #{command.string}"
          @addOutput outcomes.join("\n")

  enterHandler: ->
    command = @getCommand()
    command.string = command.string.trim()

    if @child?
      @addOutput command.string
      @child.stdin.write "#{command.string}\n"
      @clearInputText()
    else
      @addOutput "#{@cwd}$ #{command.string}"
      return @clearInputText() unless command.string

      @addHistory command.string unless @child?

      return @handleClear() if command.file is 'clear'
      return @handleCD(command) if command.file is 'cd'

      try
        @child = spawn command.file, command.args, {cwd: @cwd, env: @env}

        @child.stdin.setEncoding 'utf-8'

        @child.stdout.on 'data', (data) =>
          @addOutput data.toString()

        @child.stderr.on 'data', (data) =>
          @addOutput data.toString()

        @child.on 'close', =>
          atom.project.getRepositories()[0]?.refreshStatus() if command.file is 'git'
          @closeChild()

        @child.on 'exit', =>
          @closeChild()

        @child.on 'error', =>
          # if this command isn't continual, pass it to exec
          @exec command.string
      catch e
        @exec command.string

    @clearInputText()

  upHandler: ->
    return if @child?
    @history_index-- if @history_index > 0
    @loadHistory()

  downHandler: ->
    return if @child?
    @history_index++ if @history_index < @history.length
    @loadHistory()

  ctrlCHandler: ->
    return unless @child
    @addOutput '^C'
    @child.kill('SIGINT')

  forceKill: ->
    return unless @child
    @addOutput 'SIGKILL sent to process'
    @child.kill('SIGKILL')
