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

    it 'lexes a constant', ->
      error = Macro._lexLine @tokens, '$red', 42
      expect(error).to.equal null
      expect(@tokens).to.deep.equal [
        {type: 'const', name: '$red', value: null, line: 42}]

    it 'lexes a number', ->
      error = Macro._lexLine @tokens, '193', 42
      expect(error).to.equal null
      expect(@tokens).to.deep.equal [{type: 'number', value: 193, line: 42}]

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

    it 'parses a command including a label', ->
      Macro._lex @tokens, "absurd 123, 456, %hello"
      error = Macro._parse @ops, @tokens
      expect(error).to.equal null
      expect(@ops).to.deep.equal [
        {op: 'command', opcode: @tokens[0], args: @tokens[1..3]}]

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

    it 'adds roll with values correctly', ->
      opcode = type: 'opcode', value: 'roll', line: 42
      args = [{type: 'number', value: 63, line: 42},
              {type: 'number', value: 300, line: 42}]
      error = @macro.addCommand opcode, args
      expect(error).to.equal null
      expect(@macro.bytes).to.deep.equal [0x00, 0x05, 0x3F, 0x01, 0x2C, 0x00]
      expect(@macro._endsWithPcd).to.equal true

    it 'rejects builtin argument to roll', ->
      opcode = type: 'opcode', value: 'roll', line: 42
      args = [{type: 'number', value: 63, line: 42},
              {type: 'builtin', value: ':north', line: 42}]
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
      args = [{type: 'number', value: 2, line: 42}]
      error = @macro.addCommand opcode, args
      expect(error).to.equal null
      opcode = type: 'opcode', value: 'delay', line: 43
      args = [{type: 'number', value: 15, line: 43}]
      error = @macro.addCommand opcode, args
      expect(error).to.equal null
      expect(@macro.bytes).to.deep.equal [0x00, 0x03, 0x02, 0x0F]
      expect(@macro._endsWithPcd).to.equal false

    it 'expresses long delay as separate command', ->
      opcode = type: 'opcode', value: 'stabilization', line: 42
      args = [{type: 'number', value: 2, line: 42}]
      error = @macro.addCommand opcode, args
      expect(error).to.equal null
      opcode = type: 'opcode', value: 'delay', line: 43
      args = [{type: 'number', value: 256, line: 43}]
      error = @macro.addCommand opcode, args
      expect(error).to.equal null

      expect(@macro.bytes).to.deep.equal(
          [0x00, 0x03, 0x02, 0x00, 0x0B, 0x01, 0x00])
      expect(@macro._endsWithPcd).to.equal false

  describe '._compile', ->
    beforeEach ->
      @macro = new Macro

    it 'builds a correct macro', ->
      source = '''
      stabilization :on
      delay 1200
      end
      '''
      error = Macro._compile @macro, source
      expect(error).to.equal null
      expect(@macro.bytes).to.deep.equal(
        [0x00, 0x03, 0x02, 0x00, 0x0B, 0x04, 0xB0, 0x00])

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
          'Line 3: cannot have second opcode delay on the same line as end')
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
      stabilization :on
      delay 1200
      end
      '''
      macro = Macro.compile source
      expect(macro.bytes).to.deep.equal(
        [0x00, 0x03, 0x02, 0x00, 0x0B, 0x04, 0xB0, 0x00])

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
