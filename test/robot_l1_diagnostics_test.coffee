Robot = SpheroPwn.Robot

describe 'Robot#getL1Diagnostics', ->
  beforeEach ->
    testRecordingChannel('l1_diagnostics').then (channel) =>
      @channel = channel
      @robot = new Robot @channel

  afterEach ->
    @robot.close()

  it 'receives a large string as a result', ->
    @robot.getL1Diagnostics()
      .then (result) =>
        expect(result).to.be.a 'string'
        expect(result.length).to.be.above 300
