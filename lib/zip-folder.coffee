ZipFolderView = require './zip-folder-view'
{CompositeDisposable} = require 'atom'

module.exports =
    config:
        compressionLevel:
            type: 'integer'
            default: 6
            description: 'Valid values are 0 (off) - 9 (maximum compression), any other values will result in compression being disabled.'

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
        # require libraries that we rely on
        fs = require('fs-plus')
        JSZip = require("jszip")
        path = require('path')

        # set up a new zip class
        zip = new JSZip()
        # get the project paths from atom
        basePaths = atom.project.getPaths()

        # this gets the list tree element of the interface
        listTree = document.querySelector('.tree-view')

        # get all the selected items in the list tree
        selected = listTree.querySelectorAll('.selected > .header > span, .selected > span')

        # if we are handling more then one item then the zip name will be the projects main folder name
        # else the folder/file name is the selected items name
        if selected.length > 1
            # get an array of folders
            pieces = basePaths[0].split(path.sep)
            # get the name of the selected item replacing . with -
            name = pieces[pieces.length - 1].replace(".", "-")
            # set the save path
            savePath = basePaths[0] + path.sep + name + ".zip"
            # set the selectedBasePath to empty
            selectedBasePath = ""
        else
            # get an array of folders
            pieces = selected[0].dataset.path.split(path.sep)
            # get the name of the selected item replacing . with -
            name = pieces[pieces.length - 1].replace(".", "-")
            # remove the selected item from the save path
            pieces.splice(pieces.length - 1, 1)
            # build the target path
            targetPath = pieces.join(path.sep)
            # set the save path
            savePath = targetPath + path.sep + name + ".zip"
            # set the selectedBasePath to empty
            selectedBasePath = ""
            # if we are handling a directory set the selectedBasePath to that
            if fs.isDirectorySync selected[0].dataset.path
                selectedBasePath = selected[0].dataset.path


        # if the zip folder exists then truncate it
        # this prevents us just adding to the zip folder
        if fs.existsSync(savePath)
            fs.truncateSync(savePath, 0)

        # cycle through the selected list tree items
        d = 0
        while d < selected.length
            # get the path of the current item we are processing
            selPath = selected[d].dataset.path
            # setup a blank relative path to the file
            relPath = ""
            # setup an empty array of files
            files = [];

            # if the selected item is a directory then
            # get an array of the items inside it and
            # add that array directly to the files array
            if fs.isDirectorySync(selPath)
                files = fs.listTreeSync(selPath)
            else
                files = [selPath]

            # cycle through the files found
            fileCount = 0
            while fileCount < files.length
                # get the absolute path of the current file
                absPath = files[fileCount]

                # if the selectedBasePath is set remove it from the absolute path
                # to create the relative paths from there instead of root
                # else remove the base paths from them
                if selectedBasePath != ""
                    # remember to remove the trailing slash else paths end up absolute on extract
                    relPath = absPath.replace(selectedBasePath + path.sep, "", 'i')
                else
                    # cycle through the base paths removing them
                    # from the absolute paths to create the relative path
                    basePathsChecked = 0
                    while basePathsChecked < basePaths.length
                        # remember to remove the trailing slash else paths end up absolute on extract
                        relPath = absPath.replace(basePaths[basePathsChecked] + path.sep, "", 'i')
                        basePathsChecked++


                # if the absolute path is not a directory we add the file to the zip archive
                if (!fs.isDirectorySync(absPath))
                    zip.file(relPath, fs.readFileSync(absPath), {createFolders: true})

                fileCount++


            d++

        # get the compression level from the config
        compressionLevel = atom.config.get 'zip-folder.compressionLevel'

        # check the level is a number and that it is between 1 and 9
        # else don't compress it at all
        if compressionLevel == parseInt(compressionLevel, 10) and compressionLevel > 0 and compressionLevel < 10
            # get the contents of the zip folder ready with the selected compression
            content = zip.generate({type:"nodebuffer", compression: "DEFLATE", compressionOptions: {level: compressionLevel}})
        else
            # get the contents of the zip folder with no compression
            content = zip.generate({type:"nodebuffer"})





        # write the contents to the zip file
        fs.writeFile(savePath, content, (e) ->
            if e != null
                # let the user know there was an error saving the zip file
                atom.notifications.addError(e.message)
            else
                # alert the user we are done
                atom.notifications.addSuccess("Zip complete")
        )
