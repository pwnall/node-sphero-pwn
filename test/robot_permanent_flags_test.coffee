Robot = SpheroPwn.Robot

describe 'Robot', ->
  describe '._permanentFlagsCode', ->
    it 'returns correct values', ->
      flags =
        noSleepWhileCharging: false
        vectorDrive: true
        tailLedAlwaysOn: true
        motionTimeouts: true
        lightDoubleTap: true
        heavyDoubleTap: false
        gyroMaxAsync: true
      expect(Robot._permanentFlagsCode(flags)).to.equal 0x15A

  describe '._permanentFlagsFromCode', ->
    it 'returns correct values', ->
      goldenFlags =
        noSleepWhileCharging: false
        vectorDrive: true
        noLevelingWhileCharging: false
        tailLedAlwaysOn: true
        motionTimeouts: true
        demoMode: false
        lightDoubleTap: true
        heavyDoubleTap: false
        gyroMaxAsync: true
      expect(Robot._permanentFlagsFromCode(0x15A)).to.deep.equal goldenFlags


  describe '#setPermanentFlags', ->
    beforeEach ->
      testRecordingChannel('set_permanent_flags')
        .then (channel) =>
          @channel = channel
          @robot = new Robot @channel
          @robot.getPermanentFlags()
        .then (permanentFlags) =>
          @permanentFlags = permanentFlags

    afterEach ->
      @robot.setPermanentFlags(@permanentFlags)
        .then =>
          @robot.close()


    it 'impacts the return value of getPermanentFlags', ->
      newFlags = JSON.parse JSON.stringify(@permanentFlags)
      newFlags.vectorDrive = !newFlags.vectorDrive
      @robot.setPermanentFlags(newFlags)
        .then (result) =>
          expect(result).to.equal true
          @robot.getPermanentFlags()
        .then (robotFlags) =>
          expect(robotFlags).to.deep.equal newFlags
