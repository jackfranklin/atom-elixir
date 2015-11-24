{CompositeDisposable} = require 'atom'

#TODO: Retrieve from the environment
ELIXIR_VERSION = '1.1'

module.exports =
class ElixirAutocompleteProvider
  selector: ".source.elixir"
  disableForSelector: '.source.elixir .comment'
  server: null
  # inclusionPriority: 2
  # excludeLowerPriority: false

  constructor: ->
    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.commands.add 'atom-text-editor', 'atom-elixir:autocomplete-tab', ->
      editor = atom.workspace.getActiveTextEditor()
      atom.commands.dispatch(atom.views.getView(editor), 'autocomplete-plus:cancel')
      atom.commands.dispatch(atom.views.getView(editor), 'snippets:next-tab-stop')
    @subscriptions.add(atom.config.observe('autocomplete-plus.minimumWordLength', (@minimumWordLength) => ))

  dispose: ->
    @subscriptions.dispose()

  setServer: (server) ->
    @server = server
    suggestionList = atom.packages.getActivePackage('autocomplete-plus').mainModule.autocompleteManager.suggestionList

  getSuggestions: ({editor, bufferPosition, scopeDescriptor, prefix}) ->
    prefix = getPrefix(editor, bufferPosition)

    return unless prefix?.length >= @minimumWordLength

    new Promise (resolve) =>
      @server.getCodeCompleteSuggestions prefix, (result) ->
        suggestions = result.split('\n')

        hint = suggestions[0]
        console.log "Hint: #{hint}"
        suggestions = suggestions[1...]
        module_prefix = ''
        modules_to_add = []

        is_prefix_a_function_call = !!(prefix.match(/\.[^A-Z][^\.]*$/) || prefix.match(/^[^A-Z:][^\.]*$/))

        console.log "prefix_modules: #{prefix.split('.')[...-1]}"
        console.log "hint_modules:   #{hint.split('.')[...-1]}"

        if prefix != '' && !is_prefix_a_function_call
          prefix_modules = prefix.split('.')[...-1]
          hint_modules   = hint.split('.')[...-1]

          if prefix[-1...][0] != '.' || ("#{prefix_modules}" != "#{hint_modules}")
            modules_to_add = (m for m,i in hint_modules when m != prefix_modules[i])
            # modules_to_add = (m for m,i in hint_modules when m != prefix_modules[i] || i == hint_modules.length-1)
            module_prefix = modules_to_add.join('.') + '.' if modules_to_add.length > 0

        suggestions = suggestions.map (serverSuggestion) ->
          createSuggestion(module_prefix + serverSuggestion, prefix)

        console.log "modules_to_add: #{modules_to_add}"
        if modules_to_add.length > 0
          new_suggestion = modules_to_add.join('.')
          suggestions   = [createSuggestionForModule(new_suggestion, new_suggestion, '')].concat(suggestions)

        suggestions = sortSuggestions(suggestions)

        resolve(suggestions)

  getPrefix = (editor, bufferPosition) ->
    line = editor.getTextInRange([[bufferPosition.row, 0], bufferPosition])
    regex = /[\w0-9\._!\?\:]+$/
    line.match(regex)?[0] or ''

  createSuggestion = (serverSuggestion, prefix) ->
    [name, kind, signature, desc] = serverSuggestion.split(';')

    switch kind
      when 'function'
        createSuggestionForFunction(serverSuggestion, name, kind, signature, desc, prefix)
      when 'macro'
        createSuggestionForFunction(serverSuggestion, name, kind, signature, desc, prefix)
      when 'module'
        createSuggestionForModule(serverSuggestion, name, prefix)
      else
        console.log("Unknown kind: #{serverSuggestion}")
        {
          text: serverSuggestion
          type: 'exception'
          iconHTML: '?'
          rightLabel: kind || 'hint'
        }

  createSuggestionForFunction = (serverSuggestion, name, kind, signature, desc, prefix) ->
    args = signature.split(',')
    [func, arity] = name.split('/')
    [moduleParts..., postfix] = prefix.split('.')

    params = []
    displayText = ''
    snippet = func
    description = desc.replace(/_#LB#_/g, "\n")

    if signature
      params = args.map (arg, i) -> "${#{i+1}:#{arg.replace(/\s+\\.*$/, '')}}"
      displayText = "#{func}(#{args.join(', ')})"
    else
      params  = [1..arity].map (i) -> "${#{i}:arg#{i}}"
      displayText = "#{func}/#{arity}"

    if arity != '0'
      snippet = "#{func}(#{params.join(', ')})"

    snippet = snippet.replace(/^:/, '') + " $0"

    [type, iconHTML] = if kind == 'function'
      ['function', 'f']
    else
      ['package', 'm']

    # TODO: duplicated
    if prefix.match(/^:/)
      module = ''
      func_name = ''
      if func.match(/^:/)
        [module, func_name] = func.split('.')
      else if moduleParts.length > 0
        module = moduleParts[0]
        func_name = func
      description = "Erlang function #{module}.#{func_name}/#{arity}"

    {
      snippet: snippet
      displayText: displayText
      type: type
      rightLabel: kind
      description: description
      descriptionMoreURL: getDocURL(prefix, func, arity)
      iconHTML: iconHTML
      # replacementPrefix: prefix
    }

  createSuggestionForModule = (serverSuggestion, name, prefix) ->
    snippet = name.replace(/^:/, '')
    name = ':' + name if name.match(/^[^A-Z:]/)
    {
      snippet: snippet
      displayText: name
      type: 'class'
      iconHTML: 'M'
      rightLabel: 'module'
    }

  getDocURL = (prefix, func, arity) ->
    [moduleParts..., _postfix] = prefix.split('.')
    if prefix.match(/^:/)
      module = ''
      func_name = ''
      if func.match(/^:/)
        [module, func_name] = func.split('.')
      else if moduleParts.length > 0
        module = moduleParts[0]
        func_name = func
      "http://www.erlang.org/doc/man/#{module.replace(/^:/, '')}.html\##{func_name}-#{arity}"
    else
      module = if moduleParts.length > 0 then moduleParts.join('.') else 'Kernel'
      "http://elixir-lang.org/docs/v#{ELIXIR_VERSION}/elixir/#{module}.html\##{func}/#{arity}"

  sortSuggestions = (suggestions) ->
    sort_kind = (a, b) ->
      priority =
        exception: 0 # unknown
        class:     1 # module
        package:   2 # macro
        function:  2 # function

      priority[a.type] - priority[b.type]

    sort_text = (a, b) ->
      if a.displayText > b.displayText then 1 else if a.displayText < b.displayText then -1 else 0

    sort_func = (a, b) ->
      sort_kind(a,b) || sort_text(a, b)

    suggestions.sort(sort_func)