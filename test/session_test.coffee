Command = SpheroPwn.Command
Session = SpheroPwn.Session

describe 'Session', ->
  describe 'with a ping recording', ->
    beforeEach ->
      testRecordingChannel('session-ping').then (channel) =>
        @channel = channel

    afterEach ->
      @channel.close()

    it 'round-trips a ping command', ->
      @timeout 30000  # Talking to the real Sphero is expensive.

      session = new Session @channel
      command = new Command 0x00, 0x01, 0
      session.sendCommand(command).then (response) =>
        expect(response).to.have.property 'code', 0x00
        expect(response).to.have.property 'data'
        expect(response.data).to.deep.equal new Uint8Array()
