Robot = SpheroPwn.Robot

describe 'Robot', ->
  describe '._versionsFromData', ->
    it 'parses a v2 response correctly', ->
      data = new Buffer [0x02, 0x03, 0x01, 0xAA, 0xBB, 0x51, 0x67, 0x89
                         0x01, 0x50]
      versions = Robot._versionsFromData data
      expect(versions).to.deep.equal(
          model: 3, hardware: 1, spheroApp: { version: 0xAA, revision: 0xBB },
          bootloader: { major: 5, minor: 1 }, basic: { major: 6, minor: 7 },
          macros: { major: 8, minor: 9 }, api: { major: 1, minor: 0x50 })

  describe '#getVersions', ->
    beforeEach ->
      testRecordingChannel('get_versions')
        .then (channel) =>
          @channel = channel
          @robot = new Robot @channel

    it 'receives a response', ->
      @robot.getVersions()
        .then (versions) =>
          expect(versions).to.have.property 'model'
          expect(versions).to.have.property 'hardware'
          expect(versions).to.have.property 'bootloader'
          expect(versions).to.have.property 'basic'
          expect(versions).to.have.property 'macros'
