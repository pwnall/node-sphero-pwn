Robot = SpheroPwn.Robot

describe 'Robot', ->
  describe '._macroStatusFromData', ->
    it 'parses a no-macro response correctly', ->
      data = new Buffer [0x00, 0xAA, 0xBB]
      expect(Robot._macroStatusFromData(data)).to.equal null

    it 'parses a system macro response correctly', ->
      data = new Buffer [0x02, 0x12, 0x34]
      expect(Robot._macroStatusFromData(data)).to.deep.equal(
          macroId: 2, commandId: 0x1234, type: 'system')

    it 'parses a user macro response correctly', ->
      data = new Buffer [0x28, 0x12, 0x34]
      expect(Robot._macroStatusFromData(data)).to.deep.equal(
          macroId: 40, commandId: 0x1234, type: 'user')

    it 'parses a streaming macro response correctly', ->
      data = new Buffer [0xFE, 0x12, 0x34]
      expect(Robot._macroStatusFromData(data)).to.deep.equal(
          macroId: 254, commandId: 0x1234, type: 'streaming')

    it 'parses a temporary macro response correctly', ->
      data = new Buffer [0xFF, 0x12, 0x34]
      expect(Robot._macroStatusFromData(data)).to.deep.equal(
          macroId: 255, commandId: 0x1234, type: 'temporary')

  describe '#_saveMacro with short macro', ->
    beforeEach ->
      testRecordingChannel('macro-markers')
        .then (channel) =>
          @channel = channel
          @robot = new Robot @channel

    afterEach ->
      @robot.resetMacros()

    it 'creates a macro runnable by #runMacro', ->
      macroBytes = new Buffer([
        0x14,  # MF_ALLOW_SOD | MF_ENDSIG
        0x15, 0xAA,  # emit marker 0xAA
        0x15, 0xBB,  # emit marker 0xBB
        0x00  # end
      ])
      @robot.resetMacros()
        .then (result) =>
          expect(result).to.equal true
          @robot.abortMacro()
        .then (result) =>
          expect(result).to.equal null
          @robot._saveMacro 0xFF, macroBytes
        .then (result) =>
          expect(result).to.equal true
          new Promise (resolve, reject) =>
            events = []
            @robot.on 'macro', (event) ->
              events.push event
              resolve events if events.length is 3
            @robot.runMacro 0xFF
        .then (events) =>
          expect(events.length).to.equal 3
          expect(events[0]).to.deep.equal(
              markerId: 0xAA, macroId: 0xFF, commandId: 1)
          expect(events[1]).to.deep.equal(
              markerId: 0xBB, macroId: 0xFF, commandId: 2)
          expect(events[2]).to.deep.equal(
              markerId: 0x00, macroId: 0xFF, commandId: 3)

  describe '#_saveMacro with long macro', ->
    beforeEach ->
      testRecordingChannel('macro-long-markers')
        .then (channel) =>
          @channel = channel
          @robot = new Robot @channel

    afterEach ->
      @robot.resetMacros()

    it 'creates a macro runnable by #runMacro', ->
      macroBytes = new Buffer([
        0x14,  # MF_ALLOW_SOD | MF_ENDSIG
        0x20, 0x00, 0x20,  # 32-byte comment
          0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
          0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17,
          0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27,
          0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37,
        0x15, 0xAA,  # emit marker 0xAA
        0x15, 0xBB,  # emit marker 0xBB
        0x00  # end
      ])
      @robot.resetMacros()
        .then (result) =>
          expect(result).to.equal true
          @robot.abortMacro()
        .then (result) =>
          expect(result).to.equal null
          @robot._saveMacro 0xFF, macroBytes
        .then (result) =>
          expect(result).to.equal true
          new Promise (resolve, reject) =>
            events = []
            @robot.on 'macro', (event) ->
              events.push event
              resolve events if events.length is 3
            @robot.runMacro 0xFF
        .then (events) =>
          expect(events.length).to.equal 3
          expect(events[0]).to.deep.equal(
              markerId: 0xAA, macroId: 0xFF, commandId: 2)
          expect(events[1]).to.deep.equal(
              markerId: 0xBB, macroId: 0xFF, commandId: 3)
          expect(events[2]).to.deep.equal(
              markerId: 0x00, macroId: 0xFF, commandId: 4)

  describe '#_saveMacro with macro that exceeds maximum length', ->
    beforeEach ->
      testRecordingChannel('macro-too-long')
        .then (channel) =>
          @channel = channel
          @robot = new Robot @channel

    afterEach ->
      @robot.resetMacros()

    it 'returns a rejected promise', ->
      macroBytes = new Buffer(0x00 for i in [0...1042])
      @robot._saveMacro 0xFF, macroBytes
        .then (result) =>
          expect(false).to.equal '_saveMacro promise not rejected'
        .catch (error) =>
          expect(error).to.be.an.instanceOf Error
          expect(error).to.have.property 'message',
              'Macro length 1042 exceeds maximum of 253 bytes'

  describe '#_appendMacroFragment', ->
    beforeEach ->
      testRecordingChannel('macro-append')
        .then (channel) =>
          @channel = channel
          @robot = new Robot @channel

    afterEach ->
      @robot.resetMacros()

    it 'creates a macro runnable by #runMacro', ->
      macroBytes = new Buffer([
        0x14,  # MF_ALLOW_SOD | MF_ENDSIG
        0x20, 0x00, 0x20,  # 32-byte comment
          0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
          0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17,
          0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27,
          0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37,
        0x15, 0xAA,  # emit marker 0xAA
        0x15, 0xBB,  # emit marker 0xBB
        0x00  # end
      ])
      @robot.resetMacros()
        .then (result) =>
          expect(result).to.equal true
          @robot.abortMacro()
        .then (result) =>
          expect(result).to.equal null
          @robot._appendMacroFragment true, macroBytes.slice(0, 16)
        .then (result) =>
          expect(result).to.equal true
          @robot._appendMacroFragment false, macroBytes.slice(16)
        .then (result) =>
          expect(result).to.equal true
          new Promise (resolve, reject) =>
            events = []
            @robot.on 'macro', (event) ->
              events.push event
              resolve events if events.length is 3
            @robot.runMacro 0xFF
        .then (events) =>
          expect(events.length).to.equal 3
          expect(events[0]).to.deep.equal(
              markerId: 0xAA, macroId: 0xFF, commandId: 2)
          expect(events[1]).to.deep.equal(
              markerId: 0xBB, macroId: 0xFF, commandId: 3)
          expect(events[2]).to.deep.equal(
              markerId: 0x00, macroId: 0xFF, commandId: 4)

  describe '#loadMacro with short user macro', ->
    beforeEach ->
      testRecordingChannel('macro-load-short-user')
        .then (channel) =>
          @channel = channel
          @robot = new Robot @channel

    afterEach ->
      @robot.resetMacros()

    it 'creates a macro runnable by #runMacro', ->
      macroBytes = new Buffer([
        0x14,  # MF_ALLOW_SOD | MF_ENDSIG
        0x15, 0xAA,  # emit marker 0xAA
        0x15, 0xBB,  # emit marker 0xBB
        0x00  # end
      ])
      @robot.resetMacros()
        .then (result) =>
          expect(result).to.equal true
          @robot.abortMacro()
        .then (result) =>
          expect(result).to.equal null
          @robot._saveMacro 0x40, macroBytes
        .then (result) =>
          expect(result).to.equal true
          new Promise (resolve, reject) =>
            events = []
            @robot.on 'macro', (event) ->
              events.push event
              resolve events if events.length is 3
            @robot.runMacro 0x40
        .then (events) =>
          expect(events.length).to.equal 3
          expect(events[0]).to.deep.equal(
              markerId: 0xAA, macroId: 0x40, commandId: 1)
          expect(events[1]).to.deep.equal(
              markerId: 0xBB, macroId: 0x40, commandId: 2)
          expect(events[2]).to.deep.equal(
              markerId: 0x00, macroId: 0x40, commandId: 3)

  describe '#loadMacro with long user macro', ->
    beforeEach ->
      testRecordingChannel('macro-load-long-user')
        .then (channel) =>
          @channel = channel
          @robot = new Robot @channel

    afterEach ->
      @robot.resetMacros()

    it 'returns a rejected promise', ->
      macroBytes = new Buffer(0x00 for i in [0...1042])
      @robot.loadMacro 0x40, macroBytes
        .then (result) =>
          expect(false).to.equal '_saveMacro promise not rejected'
        .catch (error) =>
          expect(error).to.be.an.instanceOf Error
          expect(error).to.have.property 'message',
              'Macro length 1042 exceeds maximum of 253 bytes; ' +
              'only the temporary macro be longer'

  describe '#loadMacro with short temporary macro', ->
    beforeEach ->
      testRecordingChannel('macro-load-short-temp')
        .then (channel) =>
          @channel = channel
          @robot = new Robot @channel

    afterEach ->
      @robot.resetMacros()

    it 'creates a macro runnable by #runMacro', ->
      macroBytes = new Buffer([
        0x14,  # MF_ALLOW_SOD | MF_ENDSIG
        0x15, 0xAA,  # emit marker 0xAA
        0x15, 0xBB,  # emit marker 0xBB
        0x00  # end
      ])
      @robot.resetMacros()
        .then (result) =>
          expect(result).to.equal true
          @robot.abortMacro()
        .then (result) =>
          expect(result).to.equal null
          @robot._saveMacro 0xFF, macroBytes
        .then (result) =>
          expect(result).to.equal true
          new Promise (resolve, reject) =>
            events = []
            @robot.on 'macro', (event) ->
              events.push event
              resolve events if events.length is 3
            @robot.runMacro 0xFF
        .then (events) =>
          expect(events.length).to.equal 3
          expect(events[0]).to.deep.equal(
              markerId: 0xAA, macroId: 0xFF, commandId: 1)
          expect(events[1]).to.deep.equal(
              markerId: 0xBB, macroId: 0xFF, commandId: 2)
          expect(events[2]).to.deep.equal(
              markerId: 0x00, macroId: 0xFF, commandId: 3)

  describe '#loadMacro with long macro', ->
    beforeEach ->
      testRecordingChannel('macro-load-long-temp')
        .then (channel) =>
          @channel = channel
          @robot = new Robot @channel

    afterEach ->
      @robot.resetMacros()

    it 'creates a macro runnable by #runMacro', ->
      macroBytes = new Buffer([
        0x14,  # MF_ALLOW_SOD | MF_ENDSIG
        0x20, 0x00, 0x40,  # 64-byte comment A
          0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
          0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17,
          0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27,
          0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37,
          0x40, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47,
          0x50, 0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57,
          0x60, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67,
          0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77,
        0x20, 0x00, 0x40,  # 64-byte comment B
          0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F,
          0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F,
          0x28, 0x29, 0x2A, 0x2B, 0x2C, 0x2D, 0x2E, 0x2F,
          0x38, 0x39, 0x3A, 0x3B, 0x3C, 0x3D, 0x3E, 0x3F,
          0x48, 0x49, 0x4A, 0x4B, 0x4C, 0x4D, 0x4E, 0x4F,
          0x58, 0x59, 0x5A, 0x5B, 0x5C, 0x5D, 0x5E, 0x5F,
          0x68, 0x69, 0x6A, 0x6B, 0x6C, 0x6D, 0x6E, 0x6F,
          0x78, 0x79, 0x7A, 0x7B, 0x7C, 0x7D, 0x7E, 0x7F,
        0x20, 0x00, 0x40,  # 64-byte comment A
          0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
          0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17,
          0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27,
          0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37,
          0x40, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47,
          0x50, 0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57,
          0x60, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67,
          0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77,
        0x15, 0xAA,  # emit marker 0xAA
        0x20, 0x00, 0x40,  # 64-byte comment B
          0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F,
          0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F,
          0x28, 0x29, 0x2A, 0x2B, 0x2C, 0x2D, 0x2E, 0x2F,
          0x38, 0x39, 0x3A, 0x3B, 0x3C, 0x3D, 0x3E, 0x3F,
          0x48, 0x49, 0x4A, 0x4B, 0x4C, 0x4D, 0x4E, 0x4F,
          0x58, 0x59, 0x5A, 0x5B, 0x5C, 0x5D, 0x5E, 0x5F,
          0x68, 0x69, 0x6A, 0x6B, 0x6C, 0x6D, 0x6E, 0x6F,
          0x78, 0x79, 0x7A, 0x7B, 0x7C, 0x7D, 0x7E, 0x7F,
        0x20, 0x00, 0x40,  # 64-byte comment A
          0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
          0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17,
          0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27,
          0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37,
          0x40, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47,
          0x50, 0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57,
          0x60, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67,
          0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77,
        0x20, 0x00, 0x40,  # 64-byte comment B
          0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F,
          0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F,
          0x28, 0x29, 0x2A, 0x2B, 0x2C, 0x2D, 0x2E, 0x2F,
          0x38, 0x39, 0x3A, 0x3B, 0x3C, 0x3D, 0x3E, 0x3F,
          0x48, 0x49, 0x4A, 0x4B, 0x4C, 0x4D, 0x4E, 0x4F,
          0x58, 0x59, 0x5A, 0x5B, 0x5C, 0x5D, 0x5E, 0x5F,
          0x68, 0x69, 0x6A, 0x6B, 0x6C, 0x6D, 0x6E, 0x6F,
          0x78, 0x79, 0x7A, 0x7B, 0x7C, 0x7D, 0x7E, 0x7F,
        0x15, 0xBB,  # emit marker 0xBB
        0x20, 0x00, 0x40,  # 64-byte comment A
          0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
          0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17,
          0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27,
          0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37,
          0x40, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47,
          0x50, 0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57,
          0x60, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67,
          0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77,
        0x20, 0x00, 0x40,  # 64-byte comment B
          0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F,
          0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F,
          0x28, 0x29, 0x2A, 0x2B, 0x2C, 0x2D, 0x2E, 0x2F,
          0x38, 0x39, 0x3A, 0x3B, 0x3C, 0x3D, 0x3E, 0x3F,
          0x48, 0x49, 0x4A, 0x4B, 0x4C, 0x4D, 0x4E, 0x4F,
          0x58, 0x59, 0x5A, 0x5B, 0x5C, 0x5D, 0x5E, 0x5F,
          0x68, 0x69, 0x6A, 0x6B, 0x6C, 0x6D, 0x6E, 0x6F,
          0x78, 0x79, 0x7A, 0x7B, 0x7C, 0x7D, 0x7E, 0x7F,
        0x20, 0x00, 0x40,  # 64-byte comment A
          0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
          0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17,
          0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27,
          0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37,
          0x40, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47,
          0x50, 0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57,
          0x60, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67,
          0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77,
        0x00  # end
      ])
      @robot.resetMacros()
        .then (result) =>
          expect(result).to.equal true
          @robot.abortMacro()
        .then (result) =>
          expect(result).to.equal null
          @robot.loadMacro 0xFF, macroBytes
        .then (result) =>
          expect(result).to.equal true
          new Promise (resolve, reject) =>
            events = []
            @robot.on 'macro', (event) ->
              events.push event
              resolve events if events.length is 3
            @robot.runMacro 0xFF
        .then (events) =>
          expect(events.length).to.equal 3
          expect(events[0]).to.deep.equal(
              markerId: 0xAA, macroId: 0xFF, commandId: 4)
          expect(events[1]).to.deep.equal(
              markerId: 0xBB, macroId: 0xFF, commandId: 8)
          expect(events[2]).to.deep.equal(
              markerId: 0x00, macroId: 0xFF, commandId: 12)


