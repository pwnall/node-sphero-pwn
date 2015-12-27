MacroCommands = require './macro_commands.coffee'
MacroFlags = require './macro_flags.coffee'

# Compiles macros for Sphero robots.
class Macro
  # @return {Object<String, Number>} maps label names to command numbers
  labels: null

  # @return {Array<Number>} the bytes that make up the compiled macro
  bytes: null

  # Creates an empty macro.
  #
  # @param {String} source the source code to be compiled into the macro
  constructor: ->
    @_opOffsets = []
    @labels = {}
    @bytes = [0x00]
    @_endsWithPcd = false
    @_flagValues = {}
    @_varValues = {}

  # Extends the macro with a command.
  #
  # @param {Token} opcode the lexed token containing the command's opcode
  # @param {Array<Token>} args the lexed token containing the command's
  #   arguments
  # @return {String?} if not null, it represents an error message
  addCommand: (opcode, args) ->
    bytes = null  # The bytes to be added to the stream.
    hasPcd = false  # True if the command ends in a PCD byte.

    errorStart = "Line #{opcode.line}:"

    name = opcode.value
    commandData = MacroCommands[name]
    unless commandData
      return "#{errorStart} invalid command opcode #{opcode.value}"

    errorStart = "#{errorStart} #{name}"

    if args.length isnt commandData.args.length
      return "#{errorStart} takes #{commandData.args.length} arguments, got " +
          "#{args.length} arguments"

    bytes = [commandData.byteCode]
    for commandArg, index in commandData.args
      argName = commandArg.name
      argToken = args[index]

      # NOTE: Variable substitution must be done before builtin evaluation.
      if argToken.type is 'var'
        if argToken.value of @_varValues
          argToken = @_varValues[argToken.value]
        else
          return "Line #{argToken.line}: undefined variable #{argToken.value}"

      switch argToken.type
        when 'number'
          value = argToken.value
        when 'builtin'
          if commandArg.builtins
            builtinName = argToken.value.substring 1
            if builtinName of commandArg.builtins
              value = commandArg.builtins[builtinName]
            else
              return "#{errorStart} #{argName} does not accept value " +
                  argToken.value
          else
            return "#{errorStart} #{argName} does not accept builtins"
        else
          return "#{errorStart} #{argName} does not accept type " +
              argToken.type

      if value < commandArg.min
        return "#{errorStart} #{argName} value #{value} below minimum " +
            commandArg.min
      if value > commandArg.max
        return "#{errorStart} #{argName} value #{value} above maximum " +
            commandArg.max

      switch commandArg.type
        when 'uint8'
          bytes.push value
        when 'uint16'
          bytes.push value >> 8
          bytes.push value & 0xFF
        when 'sint16'
          value = 0x10000 + value if value < 0
          bytes.push value >> 8
          bytes.push value & 0xFF
        when 'bytecode'
          if value of commandArg.byteCodes
            bytes[0] = commandArg.byteCodes[value]
          else
            return "#{errorStart} #{argName} does not accept value " +
                argToken.value
        else
          throw new Error("Unimplemented argument type #{commandArg.type}")
    if commandData.pcd
      bytes.push 0x00

    # We don't ask users to remember which commands have a PCD byte. Instead,
    # we automatically convert a PCD command followed by a delay command into
    # into one command with a non-zero PCD byte.
    if @_endsWithPcd is true and bytes[0] is 0x0B and bytes[1] is 0
      @bytes[@bytes.length - 1] = bytes[2]
      bytes = []

    # TODO(pwnall): roll+delay -> roll2 optimization

    @_endsWithPcd = commandData.pcd
    unless bytes.length is 0
      @_opOffsets.push @bytes.length
      @bytes.push byte for byte in bytes

    null

  # Sets the value of a macro flag.
  #
  # @param {Token} name the lexed token containing the flag's name
  # @param {Token} value the lexed token containing the flag's value
  # @return {String?} if not null, it represents an error message
  setFlag: (name, value) ->
    if name.type isnt 'var'
      return "Line #{name.line}: invalid flag name type #{name.type}"

    flagName = name.value.substring 1
    unless flagMask = MacroFlags[flagName]
      return "Line #{name.line}: unknown flag name #{name.value}"

    flagValue = null
    switch value.type
      when 'builtin'
        if value.value is ':on'
          flagValue = true
        else if value.value is ':off'
          flagValue = false
      when 'number'
        if value.value is 1
          flagValue = true
        else if value.value is 0
          flagValue = false
      else
        return "Line #{value.line}: invalid flag value type #{value.type}"

    if flagValue is null
      return "Line #{value.line}: invalid flag value #{value.value}"

    if oldValue = @_flagValues[flagName]
      return "Line #{value.line}: flag #{name.value} already set to " +
             "#{oldValue.value} on line #{oldValue.line}"
    @_flagValues[flagName] = value

    if flagValue is true
      @bytes[0] |= flagMask

    null

  # Sets the value of a variable.
  #
  # @param {Token} name the lexed token containing the flag's name
  # @param {Token} value the lexed token containing the flag's value
  # @return {String?} if not null, it represents an error message
  setVariable: (name, value) ->
    if name.type isnt 'var'
      return "Line #{name.line}: invalid variable name type #{name.type}"
    varName = name.value

    varValue = null
    switch value.type
      when 'number'
        varValue = value
      when 'builtin'
        varValue = value
      when 'var'
        if value.value of @_varValues
          varValue = @_varValues[value.value]
        else
          return "Line #{value.line}: undefined variable #{value.value}"
      else
        return "Line #{value.line}: invalid variable value type #{value.type}"
    @_varValues[varName] = varValue

    null

  # Compiles a macro.
  #
  # @param {String} source the macro's source code
  # @return {Macro} the compiled macro
  @compile: (source) ->
    macro = new Macro
    error = @_compile macro, source
    if error isnt null
      throw new Error(error)
    macro

  # Compiles a macro.
  #
  # @param {Macro} macro receives the compiled code
  # @param {String} source the macro's source code
  # @return {String?} if not null, it represents an error message
  @_compile: (macro, source) ->
    tokens = []
    error = Macro._lex tokens, source
    return error if error isnt null

    ops = []
    error = Macro._parse ops, tokens
    return error if error isnt null

    Macro._generateCode macro, ops

  # Breaks down a macro's source code into pieces.
  #
  # @param {Array<Token>} tokenBucket receives the tokens that make up this
  #   source
  # @param {String} source the macro's source code
  # @return {String?} if not null, it represents an error message
  @_lex: (tokenBucket, source) ->
    for line, lineIndex in source.split("\n")
      error = @_lexLine tokenBucket, line, 1 + lineIndex
      return error if error isnt null
    null

  # Breaks down a line of code into its parts.
  #
  # @param {Array<Token>} tokenBucket receives the tokens that make up this
  #   line
  # @param {String} line the line of source code
  # @param {Number} lineNumber
  # @return {String?} if not null, it represents an error message
  @_lexLine: (tokenBucket, line, lineNumber) ->
    line = line.trim()  # This automatically eats whitespace.

    if line.length is 0  # End lexing when we have a blank line
      return null

    if match = /^#.*$/.exec(line)  # Comment
      token = null
    else if match = /^,/.exec(line)  # Separator
      token = null
    else if match = /^%\w+/.exec(line)  # Label
      token = type: 'label', value: match[0]
    else if match = /^:\w+/.exec(line)  # Built-in constant.
      token = type: 'builtin', value: match[0]
    else if match = /^\$\w+/.exec(line)  # Variable.
      token = type: 'var', value: match[0]
    else if match = /^-?\d+/.exec(line)  # Number
      token = type: 'number', value: parseInt(match[0])
    else if match = /^\w+/.exec(line)  # Opcode
      if match[0] of @_keywords
        token = type: 'keyword', value: match[0]
      else
        token = type: 'opcode', value: match[0]
    else
      return "Line #{lineNumber}: invalid token #{line}"

    if token isnt null
      token.line = lineNumber
      tokenBucket.push token

    @_lexLine tokenBucket, line.substring(match[0].length), lineNumber

  # List of keywords.
  @_keywords:
    let: true
    flag: true

  # Parses a sequence of macro code tokens into operations.
  #
  # @param {Array<Ops>} opBucket receives the sequence of operations
  # @param {Array<Token>} tokens the sequence of tokens to be parsed
  # @return {String?} if not null, it represents an error message
  @_parse: (opBucket, tokens) ->
    i = 0
    while i < tokens.length
      token = tokens[i]
      i += 1
      if token.type is 'label'
        opBucket.push op: 'def-label', label: token
        continue
      if token.type is 'opcode'
        args = []
        opBucket.push op: 'command', opcode: token, args: args
        while i < tokens.length and tokens[i].line is token.line
          argToken = tokens[i]
          i += 1
          if argToken.type is 'opcode' or argToken.type is 'keyword'
            return "Line #{argToken.line}: cannot have #{argToken.type} " +
                   "#{argToken.value} on the same line as #{token.value}"
          args.push argToken
        continue
      if token.type is 'keyword'
        switch token.value
          when 'flag', 'let'
            unless i < tokens.length
              construct = if token.value is 'flag' then 'flag' else 'variable'
              return "Line #{token.line}: missing #{construct} name"
            nameToken = tokens[i]
            i += 1
            unless i < tokens.length
              construct = if token.value is 'flag' then 'flag' else 'variable'
              return "Line #{token.line}: missing value for #{construct} " +
                     nameToken.value
            valueToken = tokens[i]
            i += 1
            opBucket.push op: token.value, name: nameToken, value: valueToken
        continue

      return "Line #{token.line}: unexpected #{token.type} token #{token.value}"
    null

  # Generates the code for a sequence of operations.
  #
  # @param {Macro} macro the macro that will receive the codes
  @_generateCode: (macro, ops) ->
    for op in ops
      switch op.op
        when 'command'
          error = macro.addCommand op.opcode, op.args
        when 'flag'
          error = macro.setFlag op.name, op.value
        when 'let'
          error = macro.setVariable op.name, op.value
      return error if error isnt null
    null

module.exports = Macro
