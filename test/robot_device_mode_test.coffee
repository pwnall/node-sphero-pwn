Robot = SpheroPwn.Robot

describe 'Robot#setDeviceMode', ->
  beforeEach ->
    testRecordingChannel('set_device_mode')
      .then (channel) =>
        @channel = channel
        @robot = new Robot @channel
        @robot.getDeviceMode()
      .then (deviceMode) =>
        @deviceMode = deviceMode

  afterEach ->
    @robot.setDeviceMode(@deviceMode)
      .then =>
        @robot.close()

  it 'impacts the return value of getDeviceMode', ->
    @robot.setDeviceMode('normal')
      .then (result) =>
        expect(result).to.equal true
        @robot.getDeviceMode()
      .then (deviceMode) =>
        expect(deviceMode).to.equal 'normal'
        @robot.setDeviceMode 'hack'
      .then (result) =>
        expect(result).to.equal true
        @robot.getDeviceMode()
      .then (deviceMode) =>
        expect(deviceMode).to.equal 'hack'

