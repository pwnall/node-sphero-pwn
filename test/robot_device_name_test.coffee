Robot = SpheroPwn.Robot

describe 'Robot', ->
  describe '._colorNameFromCode', ->
    it 'returns correct values', ->
      expect(Robot._colorNameFromCode(1)).to.equal 'red'
      expect(Robot._colorNameFromCode(2)).to.equal 'green'
      expect(Robot._colorNameFromCode(3)).to.equal 'blue'
      expect(Robot._colorNameFromCode(4)).to.equal 'orange'
      expect(Robot._colorNameFromCode(5)).to.equal 'purple'
      expect(Robot._colorNameFromCode(6)).to.equal 'white'
      expect(Robot._colorNameFromCode(7)).to.equal 'yellow'

    it 'returns invalid for incorrect codes', ->
      expect(Robot._colorNameFromCode(0)).to.equal 'invalid'
      expect(Robot._colorNameFromCode(-1)).to.equal 'invalid'
      expect(Robot._colorNameFromCode(8)).to.equal 'invalid'
      expect(Robot._colorNameFromCode(100)).to.equal 'invalid'

  describe '._bluetoothInfoFromData', ->
    it 'parses the structure correctly', ->
      data = new Buffer([
          0x73, 0x70, 0x68, 0x65, 0x72, 0x6F, 0x2D, 0x74,
          0x65, 0x73, 0x74, 0x00, 0x00, 0x00, 0x00, 0x00,
          0x41, 0x31, 0x42, 0x32, 0x43, 0x33, 0x44, 0x34,
          0x45, 0x35, 0x46, 0x36, 0x00, 0x06, 0x07, 0x01])
      expect(Robot._bluetoothInfoFromData(data)).to.deep.equal(
          name: 'sphero-test', mac: 'A1B2C3D4E5F6',
          colors: ['white', 'yellow', 'red'])

  describe '#setDeviceName', ->
    beforeEach ->
      testRecordingChannel('set_device_name')
        .then (channel) =>
          @channel = channel
          @robot = new Robot @channel
          @robot.on 'error', (error) => console.error error
          @robot.getBluetoothInfo()
        .then (bluetoothInfo) =>
          @name = bluetoothInfo.name

    afterEach ->
      @robot.setDeviceName(@name)
        .then =>
          @robot.close()


    it 'impacts the return value of #getBluetoothInfo', ->
      newName = 'sphero-testing'
      @robot.setDeviceName(newName)
        .then (result) =>
          expect(result).to.equal true
          @robot.getBluetoothInfo()
        .then (bluetoothInfo) =>
          expect(bluetoothInfo).to.have.property 'name', newName
