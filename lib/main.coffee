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

  getView: ->
    unless @gitGoView?
      GitGoView = require './git-go-view'
      @gitGoView = new GitGoView

      atom.workspace.addTopPanel
        item: @gitGoView

      @gitGoView.setHeight atom.config.get 'git-go.height'

    @gitGoView

  deactivate: ->
    @subscriptions.dispose()
    @gitGoView.destroy()
