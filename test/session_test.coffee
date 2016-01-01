Command = SpheroPwn.Command
Session = SpheroPwn.Session

describe 'Session', ->
  describe '._errorStringForCode', ->
    it 'handles known values', ->
      expect(Session._errorStringForCode(0x00)).to.equal 'OK'
      expect(Session._errorStringForCode(0x04)).to.equal 'Bad Command'

    it 'handles unknown values', ->
      expect(Session._errorStringForCode(0x99)).to.equal '(unknown code)'

  describe 'with a synthetic message format error recording', ->
    beforeEach ->
      testRecordingChannel('synthetic-format-error').then (channel) =>
        @channel = channel

    afterEach ->
      @channel.close()

    it 'rejects a ping command', ->
      session = new Session @channel
      command = new Command 0x00, 0x01, 4
      command.setDataUint32 0, 0xAABBCCDD
      session.sendCommand(command)
        .then (response) =>
          expect(false).to.equal 'sendCommand promise not rejected'
        .catch (error) =>
          expect(error).to.be.an.instanceOf Error
          expect(error.message).to.equal(
              'Received Sphero command response with error code Bad Command')

  describe 'with a ping recording', ->
    beforeEach ->
      testRecordingChannel('session-ping').then (channel) =>
        @channel = channel

    afterEach ->
      @channel.close()

    it 'round-trips a ping command', ->
      session = new Session @channel
      command = new Command 0x00, 0x01, 0
      session.sendCommand(command).then (response) =>
        expect(response).to.have.property 'code', 0x00
        expect(response).to.have.property 'data'
        expect(response.data).to.deep.equal new Buffer([])


  describe 'with a l1 diagnostics recording', ->
    beforeEach ->
      testRecordingChannel('session-l1_diagnostics').then (channel) =>
        @channel = channel

    afterEach ->
      @channel.close()

    it 'resolves an L1 diagnostics command', ->
      session = new Session @channel
      command = new Command 0x00, 0x40, 0
      session.sendAsyncCommand(command, 0x02).then (message) =>
        expect(message).to.have.property 'idCode', 0x02
        expect(message).to.have.property 'data'

  describe 'with a synthetic l1 diagnostics recording', ->
    beforeEach ->
      testRecordingChannel('synthetic-l1_diagnostics').then (channel) =>
        @channel = channel

    afterEach ->
      @channel.close()

    it 'resolves an L1 diagnostics command', ->
      session = new Session @channel
      command = new Command 0x00, 0x40, 0
      session.sendAsyncCommand(command, 0x02).then (message) =>
        expect(message).to.have.property 'idCode', 0x02
        expect(message.data).to.deep.equal new Buffer("Hello")

  describe 'with an inverted synthetic l1 diagnostics recording', ->
    beforeEach ->
      testRecordingChannel('synthetic-l1_diagnostics').then (channel) =>
        @channel = channel

    afterEach ->
      @channel.close()

    it 'resolves an L1 diagnostics command', ->
      session = new Session @channel
      command = new Command 0x00, 0x40, 0
      session.sendAsyncCommand(command, 0x02).then (message) =>
        expect(message).to.have.property 'idCode', 0x02
        expect(message.data).to.deep.equal new Buffer("Hello")
