Robot = SpheroPwn.Robot

describe 'Robot', ->
  describe '#appendBasicToArea', ->
    beforeEach ->
      testRecordingChannel('basic-print')
        .then (channel) =>
          @channel = channel
          @robot = new Robot @channel

    afterEach ->
      @robot.abortBasic()
        .then =>
          @robot.eraseBasicArea 'ram'
        .then =>
          @robot.close()

    it 'loads code in an empty area', ->
      basic = """
10 print "Hello from Basic"
\0"""
      @robot.on 'basicError', (error) => console.error error
      @robot.abortBasic()
        .then (result) =>
          expect(result).to.equal true
          @robot.eraseBasicArea 'ram'
        .then (result) =>
          @robot.appendBasicToArea('ram', basic)
        .then (result) =>
          expect(result).to.equal true
          new Promise (resolve, reject) =>
            @robot.runBasic 'ram', 10
            @robot.on 'basic', (event) ->
              resolve event
        .then (event) =>
          expect(event).to.deep.equal message: "Hello from Basic\n"

  describe '#loadBasic', ->
    beforeEach ->
      testRecordingChannel('basic-large-print')
        .then (channel) =>
          @channel = channel
          @robot = new Robot @channel

    afterEach ->
      @robot.abortBasic()
        .then =>
          @robot.eraseBasicArea 'ram'
        .then =>
          @robot.close()

    it 'loads code in an empty area', ->
      basic = ''
      for i in [1..30]
        basic += "#{i}0 print \"Hello from Basic line #{i}0\"\n"
        basic += "#{i}5 end\n"

      @robot.on 'basicError', (error) => console.error error
      @robot.abortBasic()
        .then (result) =>
          @robot.loadBasic('ram', basic)
        .then (result) =>
          expect(result).to.equal true
          new Promise (resolve, reject) =>
            @robot.runBasic 'ram', 240
            @robot.on 'basic', (event) ->
              resolve event
        .then (event) =>
          expect(event).to.deep.equal message: "Hello from Basic line 240\n"
