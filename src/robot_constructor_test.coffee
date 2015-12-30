Robot = SpheroPwn.Robot

describe 'Robot#constructor with a ping replay channel', ->
  beforeEach ->
    @channel = new ReplayChannel testRecordingPath('synthetic-ping')
    @robot = new Robot @channel

  afterEach ->
    @robot.close()

  it 'sets the channel correctly', ->
    expect(@robot.channel()).to.equal @channel

  it 'completes #ping with true', ->
    @robot.ping().then (result) =>
      expect(result).to.equal true
      @robot.close()

