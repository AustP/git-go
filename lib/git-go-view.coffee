{$, View} = require 'atom-space-pen-views'

TabsListView = require './tabs-list-view'
TabsDisplayView = require './tabs-display-view'

Console = require './console'

class GitGoView extends View
  @content: ->
    @div class: 'git-go', tabindex: -1, =>
      @subview 'tabsListView', new TabsListView
      @subview 'tabsDisplayView', new TabsDisplayView

  initialize: ->
    @on 'focus', => @focus()
    @on 'focusout', (e) => @unfocus(e)

    @output = $ @element.querySelector '#git-go-output'
    @input = @tabsDisplayView.gitGoInput

    @input.on 'focus', => @focus(true)
    @input.on 'focusout', (e) => @unfocus(e)

    Console.initialize @output, @input

  selectTab: (tab) ->
    @tabsListView.selectTab(tab)

  toggle: ->
    return @show() unless @isVisible() and @hasFocus()
    @hide()

  isVisible: ->
    @element.style.display == 'block'

  setHeight: (height) ->
    @element.style.height = "#{height}px"

  show: ->
    if !@tabsListView.current_tab?
      @selectTab 'console'

    @element.style.display = 'block'
    @focus()

  hide: ->
    @element.style.display = 'none'
    @unfocus()

  hasFocus: ->
    @is(':focus') or document.activeElement is @element or document.activeElement.matches('.git-go atom-text-editor')

  focus: (already_focused) ->
    @addClass 'focused'
    return @element.focus() unless @tabsListView.current_tab == 'console'
    @input.focus() unless already_focused

  unfocus: (e) ->
    return if e and e.relatedTarget and e.relatedTarget.matches '.git-go, .git-go *'
    @removeClass 'focused'
    atom.workspace.getActivePane().activate()

  destroy: ->
    @detach()

module.exports = GitGoView
