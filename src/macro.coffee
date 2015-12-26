# Compiles macros for Sphero robots.
class Macro
  # @return {Object<String, Number>} maps label names to command numbers
  labels: null
  bytes: null

  # Creates an empty macro.
  #
  # @param {String} source the source code to be compiled into the macro
  constructor: ->
    @_opOffsets = []
    @labels = {}
    @bytes = [0x00]
    @_endsWithPcd = false

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
    commandData = Macro._commands[name]
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

    @_endsWithPcd = commandData.pcd
    unless bytes.length is 0
      @_opOffsets.push @bytes.length
      @bytes.push byte for byte in bytes

    null

  # Command information used by the macro code generator.
  @_commands = {
    end: { byteCode: 0x00, args: [], pcd: false }
    stabilization: {
      byteCode: 0x03
      args: [{
        name: 'flag'
        type: 'uint8', min: 0, max: 2
        builtins: { off: 0, reset_on: 1, on: 2 }
      }]
      pcd: true
    }
    heading: {
      byteCode: 0x04
      args: [{
        name: 'heading'
        type: 'uint16', min: 0, max: 359
      }]
      pcd: true
    }
    roll: {
      byteCode: 0x05
      args: [{
        name: 'speed',
        type: 'uint8', min: 0, max: 0xFF
      }, {
        name: 'heading'
        type: 'uint16', min: 0, max: 359
      }]
      pcd: true
    }
    rgb: {
      byteCode: 0x07
      args: [{
        name: 'red',
        type: 'uint8', min: 0, max: 0xFF
      }, {
        name: 'green',
        type: 'uint8', min: 0, max: 0xFF
      }, {
        name: 'blue',
        type: 'uint8', min: 0, max: 0xFF
      }]
      pcd: true
    }
    backled: {
      byteCode: 0x09
      args: [{
        name: 'intensity',
        type: 'uint8', min: 0, max: 0xFF
      }]
      pcd: true
    }
    motor: {
      byteCode: 0x0A
      args: [{
        name: 'leftMode',
        type: 'uint8', min: 0, max: 4
        builtins: { off: 0, forward: 1, reverse: 2, brake: 3, ignore: 4 }
      }, {
        name: 'leftPower',
        type: 'uint8', min: 0, max: 255
      }, {
        name: 'rightMode',
        type: 'uint8', min: 0, max: 4
        builtins: { off: 0, forward: 1, reverse: 2, brake: 3, ignore: 4 }
      }, {
        name: 'rightPower',
        type: 'uint8', min: 0, max: 255
      }]
      pcd: true
    }
    delay: {
      byteCode: 0x0B
      args: [{
        name: 'time',
        type: 'uint16', min: 0, max: 0xFFFF
      }]
      pcd: false
    }
    rgbfade: {
      byteCode: 0x14
      args: [{
        name: 'red',
        type: 'uint8', min: 0, max: 0xFF
      }, {
        name: 'green',
        type: 'uint8', min: 0, max: 0xFF
      }, {
        name: 'blue',
        type: 'uint8', min: 0, max: 0xFF
      }, {
        name: 'duration',
        type: 'uint16', min: 0, max: 0xFFFF
      }]
      pcd: true
    }
    marker: {
      byteCode: 0x15
      args: [{
        name: 'value',
        type: 'uint8', min: 0, max: 0xFF
      }]
      pcd: false
    }
    speed: {
      byteCode: 0x25
      args: [{
        name: 'speed',
        type: 'uint8', min: 0, max: 0xFF
      }]
      pcd: true
    }

  }

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

    Macro._codeGen macro, ops

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
    else if match = /^\$\w+/.exec(line)  # Constant.
      token = type: 'const', name: match[0], value: null
    else if match = /^\d+/.exec(line)  # Number
      token = type: 'number', value: parseInt(match[0])
    else if match = /^\w+/.exec(line)  # Opcode
      token = type: 'opcode', value: match[0]
    else
      return "Line #{lineNumber}: invalid token #{line}"

    if token isnt null
      token.line = lineNumber
      tokenBucket.push token

    @_lexLine tokenBucket, line.substring(match[0].length), lineNumber


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
          if argToken.type is 'opcode'
            return "Line #{argToken.line}: cannot have second opcode " +
                   "#{argToken.value} on the same line as #{token.value}"
          args.push argToken
        continue
      return "Line #{token.line}: unexpected #{token.type} token #{token.value}"
    null

  # Generates the code for a sequence of operations.
  #
  # @param {Macro} macro the macro that will receive the codes
  @_codeGen: (macro, ops) ->
    for op in ops
      switch op.op
        when 'command'
          error = macro.addCommand op.opcode, op.args
      return error if error isnt null
    null

module.exports = Macro
