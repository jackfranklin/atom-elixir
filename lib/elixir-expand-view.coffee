path = require 'path'

{Emitter, Disposable, CompositeDisposable, File} = require 'atom'
{ScrollView} = require 'atom-space-pen-views'

module.exports =
class ElixirExpandedView extends ScrollView
  @content: =>

    createEditor = ->
      element = document.createElement('atom-text-editor')
      element.setAttribute('tabIndex', 0)
      editor = element.getModel()
      editor.setLineNumberGutterVisible(true)
      editor.setGrammar(atom.grammars.grammarForScopeName('source.elixir'))
      atom.commands.add element,
        'core:move-up': =>
          editor.moveUp()
        'core:move-down': =>
          editor.moveDown()
        'editor:newline': =>
          editor.insertText('\n')
        'core:move-to-top': =>
          editor.moveToTop()
        'core:move-to-bottom': =>
          editor.moveToBottom()
        'core:select-to-top': =>
          editor.selectToTop()
        'core:select-to-bottom': =>
          editor.selectToBottom()
      element

    codeEditorElement = createEditor()
    codeEditorElement.setAttribute('mini', true)

    expandOnceCodeEditorElement = createEditor()
    expandOnceCodeEditorElement.setAttribute('mini', true)
    expandOnceCodeEditorElement.removeAttribute('tabindex')

    expandCodeEditorElement = createEditor()
    expandCodeEditorElement.setAttribute('mini', true)
    expandCodeEditorElement.removeAttribute('tabindex')

    expandAllCodeEditorElement = createEditor()
    expandAllCodeEditorElement.setAttribute('mini', true)
    expandAllCodeEditorElement.removeAttribute('tabindex')

    @div class: "elixir-expand-view", style: "overflow: scroll;", =>
      @div class: 'padded', =>
        @header 'Code', class: 'header'
        @section class: 'input-block', =>
          @subview 'codeEditorElement', codeEditorElement

        @header 'Expand Once', class: 'header expandOnceHeader'
        @hr()
        @section class: 'input-block expandOnceEditorSection', =>
          @subview 'expandOnceCodeEditorElement', expandOnceCodeEditorElement
        @hr()

        @header 'Expand', class: 'header expandHeader'
        @hr()
        @section class: 'input-block expandEditorSection', =>
          @subview 'expandCodeEditorElement', expandCodeEditorElement
        @hr()

        @header 'Expand All', class: 'header expandAllHeader'
        @hr()
        @section class: 'input-block expandEditorSection', =>
          @subview 'expandAllCodeEditorElement', expandAllCodeEditorElement
        @hr()

  constructor: ({@buffer, @code, @line}) ->
    super
    @disposables = new CompositeDisposable

  initialize: ->
    @codeEditor = @codeEditorElement.getModel()
    @codeEditor.onDidChange (e) =>
      @code = @codeEditor.getText()
      @expandFullGetter @buffer, @code, @line, (result) =>
        [expandedOnce, expanded, expandedAll] = result.split('\u000B')
        @setExpandOnceCode(expandedOnce.trim())
        @setExpandCode(expanded.trim())
        @setExpandAllCode(expandedAll.trim())

    @expandOnceCodeEditor = @expandOnceCodeEditorElement.getModel()
    @expandOnceCodeEditor.setSoftWrapped(true)
    @expandOnceCodeEditor.getDecorations(class: 'cursor-line', type: 'line')[0].destroy()

    @expandCodeEditor = @expandCodeEditorElement.getModel()
    @expandCodeEditor.setSoftWrapped(true)
    @expandCodeEditor.getDecorations(class: 'cursor-line', type: 'line')[0].destroy()

    @expandAllCodeEditor = @expandAllCodeEditorElement.getModel()
    @expandAllCodeEditor.setSoftWrapped(true)
    @expandAllCodeEditor.getDecorations(class: 'cursor-line', type: 'line')[0].destroy()

  attached: ->
    return if @isAttached
    @isAttached = true

    resolve = =>
      @refreshView()

    if atom.workspace?
      resolve()
    else
      @disposables.add atom.packages.onDidActivateInitialPackages(resolve)

  serialize: ->
    deserializer: 'ElixirExpandView'
    source: @code

  destroy: ->
    @disposables.dispose()

  setExpandFullGetter: (getter) ->
    @expandFullGetter = getter

  setExpandOnceCode:(code) ->
    @expandOnceCode = code
    @expandOnceCodeEditor.setText(@expandOnceCode)

  setExpandCode:(code) ->
    @expandCode = code
    @expandCodeEditor.setText(@expandCode)

  setExpandAllCode:(code) ->
    @expandAllCode = code
    @expandAllCodeEditor.setText(@expandAllCode)

  setBuffer:(buffer) ->
    @buffer = buffer

  setLine:(line) ->
    @line = line

  setCode:(code) ->
    @code = code
    @codeEditor.setText(@code)

  refreshView: ->
    if @expandOnceCode?
      @expandOnceCodeEditor.setText(@expandOnceCode)
    if @expandCode?
      @expandCodeEditor.setText(@expandCode)
    if @expandAllCode?
      @expandAllCodeEditor.setText(@expandAllCode)

  getTitle: ->
    "Expand Macro"

  getIconName: ->
    "file-text"

  getURI: ->
    "atom-elixir://elixir-expand-views/view"
