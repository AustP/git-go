{View} = require 'atom-space-pen-views'

class TabsListView extends View
  current_tab: null

  @content: ->
    @ol class: 'tabs', click: 'switchTab', =>
      @li class: 'console', =>
        @span 'Console'
      @li class: 'files', =>
        @span 'Files'
      @li class: 'branches', =>
        @span 'Branches'
      @li class: 'tags', =>
        @span 'Tags'

  selectTab: (tab) ->
    return unless tab? or @current_tab == tab
    @current_tab = tab

    @find('.active').removeClass('active')
    @find(".#{tab}").addClass('active')

    tabsDisplayView = @parentView.tabsDisplayView
    tabsDisplayView.find('.active').removeClass('active')
    tabsDisplayView.find(".#{tab}").addClass('active')

    atom.commands.dispatch @element, 'git-go:focus'

  switchTab: (e) ->
    target = if e.target.tagName is 'SPAN' then e.target.parentNode else e.target
    return if target.classList.contains(@current_tab)
    @selectTab target.className

module.exports = TabsListView
