ZipFolderView = require './zip-folder-view'
{CompositeDisposable} = require 'atom'

module.exports = ZipFolder =
  modalPanel: null
  zipFolderView: null
  subscriptions: null

  activate: (state) ->
    @zipFolderView = new ZipFolderView(state.zipFolderViewState)
    @modalPanel = atom.workspace.addModalPanel(item: @zipFolderView.getElement(), visible: false)

    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that runs this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'zip-folder:run': => @run()
    # @subscriptions.add atom.commands.add 'atom-workspace', 'zip-folder:toggle': => @toggle()

  deactivate: ->
    @modalPanel.destroy()
    @subscriptions.dispose()
    @zipFolderView.destroy()

  serialize: ->
    zipFolderViewState: @zipFolderView.serialize()

  run: ->
    fs = require('fs-plus')
    JSZip = require("jszip")
    path = require('path')

    zip = new JSZip()
    basePaths = atom.project.getPaths()

    listTree = document.querySelector('.tree-view')

    selected = listTree.querySelectorAll('.selected > .header > span, .selected > span')

    if selected.length > 1
        pieces = basePaths[0].split(path.sep)
        name = pieces[pieces.length - 1]
        savePath = basePaths[0] + path.sep + name + ".zip"
    else
        pieces = selected[0].dataset.path.split(path.sep)
        name = pieces[pieces.length - 1]
        savePath = selected[0].dataset.path + path.sep + name + ".zip"


    if fs.existsSync(savePath)
        fs.truncateSync(savePath, 0)

    d = 0
    while d < selected.length
        output = d + 1
        path = selected[d].dataset.path
        relPath = ""
        files = [];

        if fs.isDirectorySync(path)
            files = fs.listTreeSync(path)
        else
            files = [path]

        fileCount = 0
        while fileCount < files.length
            absPath = files[fileCount]
            basePathsChecked = 0
            while basePathsChecked < basePaths.length
                relPath = absPath.replace(basePaths[basePathsChecked], "", 'i')
                basePathsChecked++

            if (!fs.isDirectorySync(absPath))
                zip.file(relPath, fs.readFileSync(absPath))

            fileCount++


        d++

    content = zip.generate({type:"nodebuffer"})

    fs.writeFile(savePath, content)

    atom.notifications.addSuccess("Zip complete")
