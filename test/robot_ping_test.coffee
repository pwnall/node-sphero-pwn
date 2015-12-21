Robot = SpheroPwn.Robot

describe 'Robot#ping', ->
  beforeEach ->
    testRecordingChannel('ping').then (channel) =>
      @channel = channel
      @robot = new Robot @channel

  afterEach ->
    @robot.close()

  it 'completes with true', ->
    @robot.ping().then (result) =>
      expect(result).to.equal true
      @robot.close()
