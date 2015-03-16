{CompositeDisposable} = require 'atom'

module.exports =
  config:
    height:
      title: 'Height'
      description: 'The height in pixels of the git-go pane'
      type: 'number'
      default: 300
      order: 1
    displayIntroduction:
      title: 'Display Introduction'
      description: 'Display the introduction on the terminal'
      type: 'boolean'
      default: true
      order: 2
    forceKillShortcut:
      title: 'Force Kill Shortcut'
      description: 'The keyboard shortcut to force kill the process'
      type: 'string'
      default: 'Ctrl-Z'
      enum: ['Ctrl-Z', 'Ctrl-X', 'Escape']
    askpassPath:
      title: 'Askpass Path'
      description: 'To enable sudo commands, add an askpass program path here. i.e. /usr/bin/ssh-askpass'
      type: 'string'
      default: ''
      order: 3

  gitGoView: null
  subscriptions: null

  activate: ->
    @subscriptions = new CompositeDisposable

    @subscriptions.add atom.commands.add('atom-workspace',
      'git-go:show': => @getView().show(),
      'git-go:hide': => @getView().hide(),
      'git-go:toggle': => @getView().toggle(),
      'git-go:focus': => @getView().focus(),
      'git-go:select-console': => @getView().selectTab('console'),
      'git-go:select-files': => @getView().selectTab('files'),
      'git-go:select-branches': => @getView().selectTab('branches'),
      'git-go:select-tags': => @getView().selectTab('tags')
    )

    @subscriptions.add atom.config.onDidChange 'git-go.height', =>
      @getView().setHeight atom.config.get 'git-go.height'

    @subscriptions.add atom.config.onDidChange 'git-go.forceKillShortcut', =>
      @getView().setForceKillShortcut atom.config.get 'git-go.forceKillShortcut'

    @subscriptions.add atom.config.onDidChange 'git-go.askpassPath', =>
      @getView().setAskpassPath atom.config.get 'git-go.askpassPath'

  getView: ->
    unless @gitGoView?
      GitGoView = require './git-go-view'
      @gitGoView = new GitGoView

      atom.workspace.addTopPanel
        item: @gitGoView

      @gitGoView.setHeight atom.config.get 'git-go.height'
      @gitGoView.setForceKillShortcut atom.config.get 'git-go.forceKillShortcut'
      @gitGoView.setAskpassPath atom.config.get 'git-go.askpassPath'

    @gitGoView

  deactivate: ->
    @subscriptions.dispose()
    @gitGoView.destroy()
