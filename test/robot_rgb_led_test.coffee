Robot = SpheroPwn.Robot

describe 'Robot', ->
  describe '#setUserRgbLed', ->
    beforeEach ->
      testRecordingChannel('set_user_rgb_led')
        .then (channel) =>
          @channel = channel
          @robot = new Robot @channel
          @robot.getUserRgbLed()
        .then (rgbLed) =>
          @rgbLed = rgbLed

    afterEach ->
      @robot.setUserRgbLed(@rgbLed)
        .then =>
          @robot.close()

    it 'impacts the return value of getUserRgbLed', ->
      newRgb =
        red: (@rgbLed.red + 32) & 0xFF
        green: (@rgbLed.green + 32) & 0xFF
        blue: (@rgbLed.blue + 32) & 0xFF
      @robot.setUserRgbLed(newRgb)
        .then (result) =>
          expect(result).to.equal true
          @robot.getUserRgbLed()
        .then (rgb) =>
          expect(rgb).to.deep.equal newRgb
