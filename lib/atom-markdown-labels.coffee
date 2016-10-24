AtomMarkdownLabelsView = require './atom-markdown-labels-view'
{requirePackages} = require 'atom-utils'
{CompositeDisposable, Emitter} = require 'atom'
fs = require 'fs'
fm = require 'front-matter'
path = require 'path'

class AtomMarkdownLabels
  atomMarkdownLabelsView: null
  modalPanel: null
  subscriptions: null
  # path_label_map = []
  label_path_map: null

  activate: (state) ->
    requirePackages('tree-view'). then ([treeView]) =>
      @atomMarkdownLabelsView = new AtomMarkdownLabelsView(state.atomMarkdownLabelsViewState)
      @modalPanel = atom.workspace.addModalPanel(item: @atomMarkdownLabelsView.getElement(), visible: false)

      # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
      @subscriptions = new CompositeDisposable

      # Register command that toggles this view
      @subscriptions.add atom.commands.add 'atom-workspace', 'atom-markdown-labels:toggle': => @toggle()

      @path_label_map = {}
      @label_path_map = {}

      # start watching all open projects for changes in markdown files
      paths = (path.join(projpath, "**", "*.md") for projpath in atom.project.getPaths())
      chokidar = require('chokidar')
      watcher = chokidar.watch(paths, {ignored: /[\/\\]\./})
      watcher.on 'unlink', @file_removed
      watcher.on 'add', @file_changed_added
      watcher.on 'change', @file_changed_added


      # hide or show label viewer if the tree view is toggled
      @subscriptions.add atom.commands.add 'atom-workspace', 'tree-view:toggle', =>
        if @tree.treeView?.element? and @view.active
          @view.show()
        else
          @view.hide()

      @subscriptions.add atom.commands.add 'atom-workspace', 'tree-view:show', =>
        if @view.active
          @view.show()

  file_removed: (file_path) =>
    # check if the deleted file is one of the ones we're tracking
    if file_path of @path_label_map
      # get the list of labels associated with this file
      file_labels = @path_label_map[file_path]
      file_labels.forEach (label) =>
        @label_path_map[label].delete file_path
        if @label_path_map[label].size is 0
          delete @label_path_map[label]
          console.log "Remove #{label} label"
      delete @path_label_map[file_path]
      @update_labels()

  file_changed_added: (file_path) =>
    fs.readFile file_path, 'utf-8', (err, data) => @process_yaml(data, file_path)

  process_yaml: (data, file_path) ->
    if !fm.test(data)
      return false
    # yaml attributes
    attribs = fm(data).attributes
    if !attribs.tags?
      return false
    attribs.tags = attribs.tags.split(", ") if typeof attribs.tags is 'string'
    delete @path_label_map[file_path]
    for label in attribs.tags
      (@label_path_map[label] ?= new Set()).add file_path
      (@path_label_map[file_path] ?= new Set()).add label
    @update_labels()

  update_labels: ->
    console.log @label_path_map
    console.log @path_label_map

  deactivate: ->
    @modalPanel.destroy()
    @subscriptions.dispose()
    @atomMarkdownLabelsView.destroy()


  serialize: ->
    atomMarkdownLabelsViewState: @atomMarkdownLabelsView.serialize()

  toggle: ->
    console.log 'AtomMarkdownLabels was toggled!'

    if @modalPanel.isVisible()
      @modalPanel.hide()
    else
      @modalPanel.show()

module.exports = new AtomMarkdownLabels
