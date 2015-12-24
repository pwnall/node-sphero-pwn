Robot = SpheroPwn.Robot

describe 'Robot', ->
  describe '._deviceModeCode', ->
    it 'returns correct values', ->
      expect(Robot._deviceModeCode('normal')).to.equal 0
      expect(Robot._deviceModeCode('hack')).to.equal 1

  describe '._deviceModeFromCode', ->
    it 'returns correct values', ->
      expect(Robot._deviceModeFromCode(0)).to.equal 'normal'
      expect(Robot._deviceModeFromCode(1)).to.equal 'hack'

  describe '#setDeviceMode', ->
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
