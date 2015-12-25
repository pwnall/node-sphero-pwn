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

  describe '#runMacro', ->
    beforeEach ->
      testRecordingChannel('macro-markers')
        .then (channel) =>
          @channel = channel
          @robot = new Robot @channel

    afterEach ->
      @robot.resetMacros()

    it 'obtains the markers in the macro', ->
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
          @robot.setMacro 0xFF, macroBytes
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
