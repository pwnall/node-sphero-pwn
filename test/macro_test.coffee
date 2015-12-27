Macro = SpheroPwn.Macro

describe 'Macro', ->
  describe '._lexLine', ->
    beforeEach ->
      @tokens = []

    it 'returns on empty lines', ->
      error = Macro._lexLine @tokens, '', 42
      expect(error).to.equal null
      expect(@tokens).to.deep.equal []

    it 'lexes an opcode', ->
      error = Macro._lexLine @tokens, 'end', 42
      expect(error).to.equal null
      expect(@tokens).to.deep.equal [{type: 'opcode', value: 'end', line: 42}]

    it 'lexes a label', ->
      error = Macro._lexLine @tokens, '%home', 42
      expect(error).to.equal null
      expect(@tokens).to.deep.equal [{type: 'label', value: '%home', line: 42}]

    it 'lexes a built-in value', ->
      error = Macro._lexLine @tokens, ':on', 42
      expect(error).to.equal null
      expect(@tokens).to.deep.equal [{type: 'builtin', value: ':on', line: 42}]

    it 'lexes a variable', ->
      error = Macro._lexLine @tokens, '$red', 42
      expect(error).to.equal null
      expect(@tokens).to.deep.equal [
        {type: 'var', value: '$red', line: 42}]

    it 'lexes the flag keyword', ->
      error = Macro._lexLine @tokens, 'flag', 42
      expect(error).to.equal null
      expect(@tokens).to.deep.equal [
        {type: 'keyword', value: 'flag', line: 42}]

    it 'lexes the let keyword', ->
      error = Macro._lexLine @tokens, 'let', 42
      expect(error).to.equal null
      expect(@tokens).to.deep.equal [
        {type: 'keyword', value: 'let', line: 42}]

    it 'lexes a number', ->
      error = Macro._lexLine @tokens, '193', 42
      expect(error).to.equal null
      expect(@tokens).to.deep.equal [{type: 'number', value: 193, line: 42}]

    it 'lexes a negative number', ->
      error = Macro._lexLine @tokens, '-193', 42
      expect(error).to.equal null
      expect(@tokens).to.deep.equal [{type: 'number', value: -193, line: 42}]

    it 'lexes a comment', ->
      error = Macro._lexLine @tokens, '# end all things', 42
      expect(error).to.equal null
      expect(@tokens).to.deep.equal []

    it 'barfs at unknown characters', ->
      error = Macro._lexLine @tokens, '^derp', 42
      expect(error).to.equal 'Line 42: invalid token ^derp'
      expect(@tokens).to.deep.equal []

    it 'lexes a sequence of tokens', ->
      error = Macro._lexLine @tokens, '%home rgb 255, 128 0  # Orange', 42
      expect(error).to.equal null
      expect(@tokens).to.deep.equal [
        {type: 'label', value: '%home', line: 42},
        {type: 'opcode', value: 'rgb', line: 42},
        {type: 'number', value: 255, line: 42},
        {type: 'number', value: 128, line: 42},
        {type: 'number', value: 0, line: 42},
      ]

  describe '._lex', ->
    beforeEach ->
      @tokens = []

    it 'lexes emptiness', ->
      error = Macro._lex @tokens, ''
      expect(error).to.equal null
      expect(@tokens).to.deep.equal []

    it 'lexes an empty line', ->
      error = Macro._lex @tokens, "\n"
      expect(error).to.equal null
      expect(@tokens).to.deep.equal []

    it 'lexes multiple lines', ->
      error = Macro._lex @tokens, "%home\n# Glow orange\nrgb 255, 128, 0\n"
      expect(error).to.equal null
      expect(@tokens).to.deep.equal [
        {type: 'label', value: '%home', line: 1},
        {type: 'opcode', value: 'rgb', line: 3},
        {type: 'number', value: 255, line: 3},
        {type: 'number', value: 128, line: 3},
        {type: 'number', value: 0, line: 3},
      ]

    it 'passes up _lexLine errors', ->
      error = Macro._lex @tokens, "%home\n# Glow\n  ^derp\nrgb 255, 128, 0\n"
      expect(error).to.equal 'Line 3: invalid token ^derp'
      expect(@tokens).to.deep.equal [
        {type: 'label', value: '%home', line: 1},
      ]

  describe '._parse', ->
    beforeEach ->
      @ops = []
      @tokens = []

    it 'parses emptiness', ->
      error = Macro._parse @ops, []
      expect(error).to.equal null
      expect(@ops).to.deep.equal []

    it 'parses a label definition', ->
      Macro._lex @tokens, "%hello"
      error = Macro._parse @ops, @tokens
      expect(error).to.equal null
      expect(@ops).to.deep.equal [{op: 'def-label', label: @tokens[0]}]

    it 'parses a command that includes a label', ->
      Macro._lex @tokens, "absurd 123, 456, %hello"
      error = Macro._parse @ops, @tokens
      expect(error).to.equal null
      expect(@ops).to.deep.equal [
        {op: 'command', opcode: @tokens[0], args: @tokens[1..3]}]

    it 'parses a command that includes a var', ->
      Macro._lex @tokens, "absurd 123, 456, $red"
      error = Macro._parse @ops, @tokens
      expect(error).to.equal null
      expect(@ops).to.deep.equal [
        {op: 'command', opcode: @tokens[0], args: @tokens[1..3]}]

    it 'rejects two commands on the same line', ->
      Macro._lex @tokens, "stabilize end"
      error = Macro._parse @ops, @tokens
      expect(error).to.equal(
          'Line 1: cannot have opcode end on the same line as stabilize')
      expect(@ops).to.deep.equal [
          {op: 'command', opcode: @tokens[0], args: []}]

    it 'rejects a command that includes a keyword', ->
      Macro._lex @tokens, "stabilize let"
      error = Macro._parse @ops, @tokens
      expect(error).to.equal(
          'Line 1: cannot have keyword let on the same line as stabilize')
      expect(@ops).to.deep.equal [
          {op: 'command', opcode: @tokens[0], args: []}]

    it 'parses a let assignment', ->
      Macro._lex @tokens, "let $red 255"
      error = Macro._parse @ops, @tokens
      expect(error).to.equal null
      expect(@ops).to.deep.equal [
        {op: 'let', name: @tokens[1], value: @tokens[2]}]

    it 'rejects a let assignment without a name', ->
      Macro._lex @tokens, "let"
      error = Macro._parse @ops, @tokens
      expect(error).to.equal 'Line 1: missing variable name'
      expect(@ops).to.deep.equal []

    it 'rejects a let assignment without a value', ->
      Macro._lex @tokens, "let $red"
      error = Macro._parse @ops, @tokens
      expect(error).to.equal 'Line 1: missing value for variable $red'
      expect(@ops).to.deep.equal []

    it 'parses a flag assignment', ->
      Macro._lex @tokens, "flag $exclusiveDrive :on"
      error = Macro._parse @ops, @tokens
      expect(error).to.equal null
      expect(@ops).to.deep.equal [
        {op: 'flag', name: @tokens[1], value: @tokens[2]}]

    it 'rejects a flag assignment without a name', ->
      Macro._lex @tokens, "flag"
      error = Macro._parse @ops, @tokens
      expect(error).to.equal 'Line 1: missing flag name'
      expect(@ops).to.deep.equal []

    it 'rejects a flag assignment without a value', ->
      Macro._lex @tokens, "flag $exclusiveDrive"
      error = Macro._parse @ops, @tokens
      expect(error).to.equal 'Line 1: missing value for flag $exclusiveDrive'
      expect(@ops).to.deep.equal []

  describe '#constructor', ->
    it 'creates an empty macro', ->
      macro = new Macro
      expect(macro.bytes).to.deep.equal [0x00]
      expect(macro.labels).to.deep.equal {}
      expect(macro._endsWithPcd).to.equal false

  describe '#addCommand', ->
    beforeEach ->
      @macro = new Macro

    it 'adds end correctly', ->
      opcode = type: 'opcode', value: 'end', line: 42
      args = []
      error = @macro.addCommand opcode, args
      expect(error).to.equal null
      expect(@macro.bytes).to.deep.equal [0x00, 0x00]
      expect(@macro._endsWithPcd).to.equal false

    it 'rejects invalid opcode', ->
      opcode = type: 'opcode', value: 'nosuchop', line: 42
      args = []
      error = @macro.addCommand opcode, args
      expect(error).to.equal 'Line 42: invalid command opcode nosuchop'
      expect(@macro.bytes).to.deep.equal [0x00]
      expect(@macro._endsWithPcd).to.equal false

    it 'rejects extra arguments to end', ->
      opcode = type: 'opcode', value: 'end', line: 42
      args = [{type: 'number', value: 2, line: 42}]
      error = @macro.addCommand opcode, args
      expect(error).to.equal 'Line 42: end takes 0 arguments, got 1 arguments'
      expect(@macro.bytes).to.deep.equal [0x00]

    it 'adds stabilization with value correctly', ->
      opcode = type: 'opcode', value: 'stabilization', line: 42
      args = [{type: 'number', value: 2, line: 42}]
      error = @macro.addCommand opcode, args
      expect(error).to.equal null
      expect(@macro.bytes).to.deep.equal [0x00, 0x03, 0x02, 0x00]
      expect(@macro._endsWithPcd).to.equal true

    it 'adds stabilization with builtin correctly', ->
      opcode = type: 'opcode', value: 'stabilization', line: 42
      args = [{type: 'builtin', value: ':reset_on', line: 42}]
      error = @macro.addCommand opcode, args
      expect(error).to.equal null
      expect(@macro.bytes).to.deep.equal [0x00, 0x03, 0x01, 0x00]
      expect(@macro._endsWithPcd).to.equal true

    it 'adds stabilization with variable correctly', ->
      name = type: 'var', value: '$stabilization', line: 40
      value = type: 'builtin', value: ':reset_on', line: 40
      error = @macro.setVariable name, value
      expect(error).to.equal null

      opcode = type: 'opcode', value: 'stabilization', line: 42
      args = [{ type: 'var', value: '$stabilization', line: 42 }]
      error = @macro.addCommand opcode, args
      expect(error).to.equal null
      expect(@macro.bytes).to.deep.equal [0x00, 0x03, 0x01, 0x00]
      expect(@macro._endsWithPcd).to.equal true

    it 'rejects undefined variable name', ->
      opcode = type: 'opcode', value: 'stabilization', line: 42
      args = [{ type: 'var', value: '$stabilization', line: 42 }]
      error = @macro.addCommand opcode, args
      expect(error).to.equal 'Line 42: undefined variable $stabilization'
      expect(@macro.bytes).to.deep.equal [0x00]
      expect(@macro._endsWithPcd).to.equal false

    it 'rejects label argument to stabilization', ->
      opcode = type: 'opcode', value: 'stabilization', line: 42
      args = [{type: 'label', value: '%home', line: 42}]
      error = @macro.addCommand opcode, args
      expect(error).to.equal(
          'Line 42: stabilization flag does not accept type label')
      expect(@macro.bytes).to.deep.equal [0x00]
      expect(@macro._endsWithPcd).to.equal false

    it 'rejects invalid builtin argument to stabilization', ->
      opcode = type: 'opcode', value: 'stabilization', line: 42
      args = [{type: 'builtin', value: ':invalid', line: 42}]
      error = @macro.addCommand opcode, args
      expect(error).to.equal(
          'Line 42: stabilization flag does not accept value :invalid')
      expect(@macro.bytes).to.deep.equal [0x00]
      expect(@macro._endsWithPcd).to.equal false

    it 'rejects underflow value argument to stabilization', ->
      opcode = type: 'opcode', value: 'stabilization', line: 42
      args = [{type: 'number', value: -1, line: 42}]
      error = @macro.addCommand opcode, args
      expect(error).to.equal(
          'Line 42: stabilization flag value -1 below minimum 0')
      expect(@macro.bytes).to.deep.equal [0x00]
      expect(@macro._endsWithPcd).to.equal false

    it 'rejects overflow value argument to stabilization', ->
      opcode = type: 'opcode', value: 'stabilization', line: 42
      args = [{type: 'number', value: 16, line: 42}]
      error = @macro.addCommand opcode, args
      expect(error).to.equal(
          'Line 42: stabilization flag value 16 above maximum 2')
      expect(@macro.bytes).to.deep.equal [0x00]
      expect(@macro._endsWithPcd).to.equal false

    it 'rejects invalid builtin via variable argument to stabilization', ->
      name = type: 'var', value: '$stabilization', line: 40
      value = type: 'builtin', value: ':invalid', line: 40
      error = @macro.setVariable name, value
      expect(error).to.equal null

      opcode = type: 'opcode', value: 'stabilization', line: 42
      args = [{ type: 'var', value: '$stabilization', line: 42 }]
      error = @macro.addCommand opcode, args
      expect(error).to.equal(
          'Line 42: stabilization flag does not accept value :invalid')
      expect(@macro.bytes).to.deep.equal [0x00]
      expect(@macro._endsWithPcd).to.equal false

    it 'rejects underflow value via variable argument to stabilization', ->
      name = type: 'var', value: '$stabilization', line: 40
      value = type: 'number', value: -1, line: 40
      error = @macro.setVariable name, value
      expect(error).to.equal null

      opcode = type: 'opcode', value: 'stabilization', line: 42
      args = [{ type: 'var', value: '$stabilization', line: 42 }]
      error = @macro.addCommand opcode, args
      expect(error).to.equal(
          'Line 42: stabilization flag value -1 below minimum 0')
      expect(@macro.bytes).to.deep.equal [0x00]
      expect(@macro._endsWithPcd).to.equal false

    it 'rejects overflow value via variable argument to stabilization', ->
      name = type: 'var', value: '$stabilization', line: 40
      value = type: 'number', value: 16, line: 40
      error = @macro.setVariable name, value
      expect(error).to.equal null

      opcode = type: 'opcode', value: 'stabilization', line: 42
      args = [{ type: 'var', value: '$stabilization', line: 42 }]
      error = @macro.addCommand opcode, args
      expect(error).to.equal(
          'Line 42: stabilization flag value 16 above maximum 2')
      expect(@macro.bytes).to.deep.equal [0x00]
      expect(@macro._endsWithPcd).to.equal false

    it 'adds roll with values correctly', ->
      opcode = type: 'opcode', value: 'roll', line: 42
      args = [{ type: 'number', value: 63, line: 42 },
              { type: 'number', value: 300, line: 42 }]
      error = @macro.addCommand opcode, args
      expect(error).to.equal null
      expect(@macro.bytes).to.deep.equal [0x00, 0x05, 0x3F, 0x01, 0x2C, 0x00]
      expect(@macro._endsWithPcd).to.equal true

    it 'rejects builtin argument to roll', ->
      opcode = type: 'opcode', value: 'roll', line: 42
      args = [{ type: 'number', value: 63, line: 42 },
              { type: 'builtin', value: ':north', line: 42 }]
      error = @macro.addCommand opcode, args
      expect(error).to.equal 'Line 42: roll heading does not accept builtins'
      expect(@macro.bytes).to.deep.equal [0x00]
      expect(@macro._endsWithPcd).to.equal false

    it 'rejects builtin argument via variable to roll', ->
      name = type: 'var', value: '$roll', line: 40
      value = type: 'builtin', value: ':north', line: 40
      error = @macro.setVariable name, value
      expect(error).to.equal null

      opcode = type: 'opcode', value: 'roll', line: 42
      args = [{ type: 'number', value: 63, line: 42 },
              { type: 'var', value: '$roll', line: 42 }]
      error = @macro.addCommand opcode, args
      expect(error).to.equal 'Line 42: roll heading does not accept builtins'
      expect(@macro.bytes).to.deep.equal [0x00]
      expect(@macro._endsWithPcd).to.equal false

    it 'adds delay with value correctly', ->
      opcode = type: 'opcode', value: 'delay', line: 42
      args = [{type: 'number', value: 1200, line: 42}]
      error = @macro.addCommand opcode, args
      expect(error).to.equal null
      expect(@macro.bytes).to.deep.equal [0x00, 0x0B, 0x04, 0xB0]
      expect(@macro._endsWithPcd).to.equal false

    it 'folds short delay into stabilization PCD', ->
      opcode = type: 'opcode', value: 'stabilization', line: 42
      args = [{ type: 'number', value: 2, line: 42 }]
      error = @macro.addCommand opcode, args
      expect(error).to.equal null
      opcode = type: 'opcode', value: 'delay', line: 43
      args = [{ type: 'number', value: 15, line: 43 }]
      error = @macro.addCommand opcode, args
      expect(error).to.equal null
      expect(@macro.bytes).to.deep.equal [0x00, 0x03, 0x02, 0x0F]
      expect(@macro._endsWithPcd).to.equal false

    it 'expresses long delay as separate command', ->
      opcode = type: 'opcode', value: 'stabilization', line: 42
      args = [{ type: 'number', value: 2, line: 42 }]
      error = @macro.addCommand opcode, args
      expect(error).to.equal null
      opcode = type: 'opcode', value: 'delay', line: 43
      args = [{ type: 'number', value: 256, line: 43 }]
      error = @macro.addCommand opcode, args
      expect(error).to.equal null
      expect(@macro.bytes).to.deep.equal(
          [0x00, 0x03, 0x02, 0x00, 0x0B, 0x01, 0x00])
      expect(@macro._endsWithPcd).to.equal false

    it 'adds sysspeed with register 1 correctly', ->
      opcode = type: 'opcode', value: 'sysspeed', line: 42
      args = [{ type: 'number', value: 1, line: 42 },
              { type: 'number', value: 1200, line: 42 }]
      error = @macro.addCommand opcode, args
      expect(error).to.equal null
      expect(@macro.bytes).to.deep.equal [0x00, 0x0F, 0x04, 0xB0]
      expect(@macro._endsWithPcd).to.equal false

    it 'adds sysspeed with register 2 correctly', ->
      opcode = type: 'opcode', value: 'sysspeed', line: 42
      args = [{ type: 'number', value: 2, line: 42 },
              { type: 'number', value: 1200, line: 42 }]
      error = @macro.addCommand opcode, args
      expect(error).to.equal null
      expect(@macro.bytes).to.deep.equal [0x00, 0x10, 0x04, 0xB0]
      expect(@macro._endsWithPcd).to.equal false

    it 'adds sysspeed with builtin :spd2 correctly', ->
      opcode = type: 'opcode', value: 'sysspeed', line: 42
      args = [{ type: 'builtin', value: ':spd2', line: 42 },
              { type: 'number', value: 1200, line: 42 }]
      error = @macro.addCommand opcode, args
      expect(error).to.equal null
      expect(@macro.bytes).to.deep.equal [0x00, 0x10, 0x04, 0xB0]
      expect(@macro._endsWithPcd).to.equal false

    it 'rejects sysspeed with invalid register correctly', ->
      opcode = type: 'opcode', value: 'sysspeed', line: 42
      args = [{ type: 'number', value: 5, line: 42 },
              { type: 'number', value: 1200, line: 42 }]
      error = @macro.addCommand opcode, args
      expect(error).to.equal(
          'Line 42: sysspeed register does not accept value 5')
      expect(@macro.bytes).to.deep.equal [0x00]
      expect(@macro._endsWithPcd).to.equal false

    it 'rejects sysspeed with invalid builtin correctly', ->
      opcode = type: 'opcode', value: 'sysspeed', line: 42
      args = [{ type: 'builtin', value: ':spd5', line: 42 },
              { type: 'number', value: 1200, line: 42 }]
      error = @macro.addCommand opcode, args
      expect(error).to.equal(
          'Line 42: sysspeed register does not accept value :spd5')
      expect(@macro.bytes).to.deep.equal [0x00]
      expect(@macro._endsWithPcd).to.equal false

    it 'adds timedrotate with positive angularSpeed correctly', ->
      opcode = type: 'opcode', value: 'timedrotate', line: 42
      args = [{ type: 'number', value: 720, line: 42 },
              { type: 'number', value: 4000, line: 42 }]
      error = @macro.addCommand opcode, args
      expect(error).to.equal null
      expect(@macro.bytes).to.deep.equal [0x00, 0x1A, 0x02, 0xD0, 0x0F, 0xA0]
      expect(@macro._endsWithPcd).to.equal false

    it 'adds timedrotate with negative angularSpeed correctly', ->
      opcode = type: 'opcode', value: 'timedrotate', line: 42
      args = [{ type: 'number', value: -720, line: 42 },
              { type: 'number', value: 5000, line: 42 }]
      error = @macro.addCommand opcode, args
      expect(error).to.equal null
      expect(@macro.bytes).to.deep.equal [0x00, 0x1A, 0xFD, 0x30, 0x13, 0x88]
      expect(@macro._endsWithPcd).to.equal false

  describe '#setFlag', ->
    beforeEach ->
      @macro = new Macro

    it 'processes a correct :on assignment', ->
      name = type: 'var', value: '$exclusiveDrive', line: 42
      value = type: 'builtin', value: ':on', line: 42
      error = @macro.setFlag name, value
      expect(error).to.equal null
      expect(@macro.bytes).to.deep.equal [0x02]

    it 'processes a correct :off assignment', ->
      name = type: 'var', value: '$exclusiveDrive', line: 42
      value = type: 'builtin', value: ':off', line: 42
      error = @macro.setFlag name, value
      expect(error).to.equal null
      expect(@macro.bytes).to.deep.equal [0x00]

    it 'processes a correct 1 assignment', ->
      name = type: 'var', value: '$exclusiveDrive', line: 42
      value = type: 'number', value: 1, line: 42
      error = @macro.setFlag name, value
      expect(error).to.equal null
      expect(@macro.bytes).to.deep.equal [0x02]

    it 'processes a correct 0 assignment', ->
      name = type: 'var', value: '$exclusiveDrive', line: 42
      value = type: 'number', value: 0, line: 42
      error = @macro.setFlag name, value
      expect(error).to.equal null
      expect(@macro.bytes).to.deep.equal [0x00]

    it 'processes two correct :on assignments', ->
      name = type: 'var', value: '$exclusiveDrive', line: 42
      value = type: 'builtin', value: ':on', line: 42
      error = @macro.setFlag name, value
      expect(error).to.equal null
      name = type: 'var', value: '$stopOnDisconnect', line: 42
      error = @macro.setFlag name, value
      expect(error).to.equal null
      expect(@macro.bytes).to.deep.equal [0x06]

    it 'rejects an assignment to a non-variable flag name', ->
      name = type: 'number', value: '42', line: 42
      value = type: 'builtin', value: ':on', line: 42
      error = @macro.setFlag name, value
      expect(error).to.equal 'Line 42: invalid flag name type number'
      expect(@macro.bytes).to.deep.equal [0x00]

    it 'rejects an assignment to an invalid flag name', ->
      name = type: 'var', value: '$noSuchFlag', line: 42
      value = type: 'builtin', value: ':on', line: 42
      error = @macro.setFlag name, value
      expect(error).to.equal 'Line 42: unknown flag name $noSuchFlag'
      expect(@macro.bytes).to.deep.equal [0x00]

    it 'rejects a label assignment', ->
      name = type: 'var', value: '$exclusiveDrive', line: 42
      value = type: 'label', value: '%home', line: 42
      error = @macro.setFlag name, value
      expect(error).to.equal 'Line 42: invalid flag value type label'
      expect(@macro.bytes).to.deep.equal [0x00]

    it 'rejects an invalid builtin assignment', ->
      name = type: 'var', value: '$exclusiveDrive', line: 42
      value = type: 'builtin', value: ':invalid', line: 42
      error = @macro.setFlag name, value
      expect(error).to.equal 'Line 42: invalid flag value :invalid'
      expect(@macro.bytes).to.deep.equal [0x00]

    it 'rejects an invalid value assignment', ->
      name = type: 'var', value: '$exclusiveDrive', line: 42
      value = type: 'number', value: 2, line: 42
      error = @macro.setFlag name, value
      expect(error).to.equal 'Line 42: invalid flag value 2'
      expect(@macro.bytes).to.deep.equal [0x00]

    it 'rejects a double assignment', ->
      name = type: 'var', value: '$exclusiveDrive', line: 42
      value = type: 'builtin', value: ':off', line: 42
      error = @macro.setFlag name, value
      expect(error).to.equal null
      expect(@macro.bytes).to.deep.equal [0x00]

      name = type: 'var', value: '$exclusiveDrive', line: 44
      value = type: 'builtin', value: ':on', line: 44
      error = @macro.setFlag name, value
      expect(error).to.equal(
          'Line 44: flag $exclusiveDrive already set to :off on line 42')
      expect(@macro.bytes).to.deep.equal [0x00]

  describe '#setVariable', ->
    beforeEach ->
      @macro = new Macro

    it 'processes a correct builtin assignment', ->
      name = type: 'var', value: '$red', line: 42
      value = type: 'builtin', value: ':on', line: 42
      error = @macro.setVariable name, value
      expect(error).to.equal null
      expect(@macro.bytes).to.deep.equal [0x00]
      expect(@macro._varValues['$red']).to.equal value

    it 'processes a correct number assignment', ->
      name = type: 'var', value: '$red', line: 42
      value = type: 'number', value: 5, line: 42
      error = @macro.setVariable name, value
      expect(error).to.equal null
      expect(@macro.bytes).to.deep.equal [0x00]
      expect(@macro._varValues['$red']).to.equal value

    it 'processes a correct variable assignment', ->
      name = type: 'var', value: '$red', line: 42
      value = type: 'number', value: 5, line: 42
      error = @macro.setVariable name, value
      expect(error).to.equal null

      name2 = type: 'var', value: '$green', line: 44
      value2 = type: 'var', value: '$red', line: 44
      error = @macro.setVariable name2, value2
      expect(error).to.equal null
      expect(@macro.bytes).to.deep.equal [0x00]
      expect(@macro._varValues['$green']).to.equal value

    it 'rejects an assignment to a non-variable name', ->
      name = type: 'number', value: '42', line: 42
      value = type: 'builtin', value: ':on', line: 42
      error = @macro.setVariable name, value
      expect(error).to.equal 'Line 42: invalid variable name type number'
      expect(@macro.bytes).to.deep.equal [0x00]

    it 'rejects an undefined variable assignment', ->
      name = type: 'var', value: '$green', line: 42
      value = type: 'var', value: '$red', line: 42
      error = @macro.setVariable name, value
      expect(error).to.equal 'Line 42: undefined variable $red'
      expect(@macro.bytes).to.deep.equal [0x00]

    it 'rejects a keyword assignment', ->
      name = type: 'var', value: '$green', line: 42
      value = type: 'keyword', value: 'var', line: 42
      error = @macro.setVariable name, value
      expect(error).to.equal 'Line 42: invalid variable value type keyword'
      expect(@macro.bytes).to.deep.equal [0x00]

  describe '._generateCode', ->
    beforeEach ->
      @macro = new Macro

    it 'processes a command op correctly', ->
      op =
        op: 'command'
        opcode: { type: 'opcode', value: 'end', line: 42 }
        args: []
      error = Macro._generateCode @macro, [op]
      expect(error).to.equal null
      expect(@macro.bytes).to.deep.equal [0x00, 0x00]

    it 'reports an error in a command op correctly', ->
      op =
        op: 'command'
        opcode: { type: 'opcode', value: 'nosuchop', line: 42 }
        args: []
      error = Macro._generateCode @macro, [op]
      expect(error).to.equal 'Line 42: invalid command opcode nosuchop'
      expect(@macro.bytes).to.deep.equal [0x00]

    it 'processes a flag op correctly', ->
      op =
        op: 'flag'
        name: { type: 'var', value: '$exclusiveDrive', line: 42 }
        value: { type: 'builtin', value: ':on', line: 42 }
      error = Macro._generateCode @macro, [op]
      expect(error).to.equal null
      expect(@macro.bytes).to.deep.equal [0x02]

    it 'reports an error in a flag op correctly', ->
      op =
        op: 'flag'
        name: { type: 'var', value: '$noSuchFlag', line: 42 }
        value: { type: 'builtin', value: ':on', line: 42 }
      error = Macro._generateCode @macro, [op]
      expect(error).to.equal 'Line 42: unknown flag name $noSuchFlag'
      expect(@macro.bytes).to.deep.equal [0x00]

    it 'processes a let op correctly', ->
      value = type: 'number', value: 1, line: 42
      op =
        op: 'let'
        name: { type: 'var', value: '$red', line: 42 }
        value: value
      error = Macro._generateCode @macro, [op]
      expect(error).to.equal null
      expect(@macro.bytes).to.deep.equal [0x00]
      expect(@macro._varValues['$red']).to.equal value

    it 'reports an error in a let op correctly', ->
      op =
        op: 'let'
        name: { type: 'var', value: '$red', line: 42 }
        value: { type: 'var', value: '$green', line: 42 }
      error = Macro._generateCode @macro, [op]
      expect(error).to.equal 'Line 42: undefined variable $green'
      expect(@macro.bytes).to.deep.equal [0x00]

  describe '._compile', ->
    beforeEach ->
      @macro = new Macro

    it 'builds a correct macro', ->
      source = '''
      flag $markerOnEnd :on
      let $stabilization :on
      stabilization $stabilization
      delay 1200
      end
      '''
      error = Macro._compile @macro, source
      expect(error).to.equal null
      expect(@macro.bytes).to.deep.equal(
        [0x10, 0x03, 0x02, 0x00, 0x0B, 0x04, 0xB0, 0x00])

    it 'reports lexing errors correctly', ->
      source = '''
      stabilization :on
      delay 1200
      end ^derp
      '''
      error = Macro._compile @macro, source
      expect(error).to.equal 'Line 3: invalid token ^derp'
      expect(@macro.bytes).to.deep.equal [0x00]

    it 'reports parsing errors correctly', ->
      source = '''
      stabilization :on
      delay 1200
      end delay 1200
      '''
      error = Macro._compile @macro, source
      expect(error).to.equal(
          'Line 3: cannot have opcode delay on the same line as end')
      expect(@macro.bytes).to.deep.equal [0x00]

    it 'reports codegen errors correctly', ->
      source = '''
      stabilization :on
      delay :none
      end
      '''
      error = Macro._compile @macro, source
      expect(error).to.equal 'Line 2: delay time does not accept builtins'

  describe '.compile', ->
    it 'builds a correct macro', ->
      source = '''
      flag $markerOnEnd :on
      let $stabilization :on
      stabilization :on
      delay 1200
      end
      '''
      macro = Macro.compile source
      expect(macro.bytes).to.deep.equal(
        [0x10, 0x03, 0x02, 0x00, 0x0B, 0x04, 0xB0, 0x00])

    it 'reports errors', ->
      source = '''
      stabilization :on
      delay 1200
      end ^derp
      '''
      try
        Macro.compile source
        expect(false).to.equal 'expected error not thrown'
      catch error
        expect(error).to.be.an.instanceOf Error
        expect(error.message).to.equal 'Line 3: invalid token ^derp'
