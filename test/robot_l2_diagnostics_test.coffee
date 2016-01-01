Robot = SpheroPwn.Robot

describe 'Robot#getL2Diagnostics', ->
  beforeEach ->
    testRecordingChannel('l2_diagnostics').then (channel) =>
      @channel = channel
      @robot = new Robot @channel
      @robot.getDeviceMode()
        .then (deviceMode) =>
          @deviceMode = deviceMode
          @robot.setDeviceMode 'hack'

  afterEach ->
    @robot.setDeviceMode(@deviceMode)
      .then =>
        @robot.close()

  it 'receives a result', ->
    @robot.getL2Diagnostics()
      .then (result) =>
        expect(result).to.equal true
      .catch (error) =>
        # TODO(pwnall): Replace this with a proper test when we get a device
        #               that can perform an L2 diagnostic.
        expect(error.message).to.equal(
            'Received Sphero command response with error code Bad Command')

