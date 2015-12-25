Command = SpheroPwn.Command

describe 'Command', ->
  describe '.checksum', ->
    it 'computes the 2s complement of the sum', ->
      buffer = new Buffer [0x01]
      expect(Command.checksum(buffer, 0, 1)).to.equal 0xFE

    it 'computes the sum of the bytes', ->
      buffer = new Buffer [0x01, 0x02, 0x03, 0x04]
      expect(Command.checksum(buffer, 0, 4)).to.equal 0xF5

    it 'respects the start parameter', ->
      buffer = new Buffer [0x01, 0x02, 0x03, 0x04]
      expect(Command.checksum(buffer, 1, 4)).to.equal 0xF6

    it 'respects the end parameter', ->
      buffer = new Buffer [0x01, 0x02, 0x03, 0x04]
      expect(Command.checksum(buffer, 1, 3)).to.equal 0xFA

    it 'works correctly on the documentation example', ->
      buffer = new Buffer [0xFF, 0xFF, 0x00, 0x01, 0x52, 0x01]
      expect(Command.checksum(buffer, 2, 6)).to.equal 0xAB

  describe '#constructor', ->
    it 'builds a ping correctly', ->
      command = new Command 0x00, 0x01, 0
      command.setSequence 0x52
      expect(command.buffer.toString('hex')).to.equal 'ffff00015201ab'

    it 'builds a noResponse ping correctly', ->
      command = new Command 0x00, 0x01, 0, noResponse: true
      command.setSequence 0x52
      expect(command.buffer.toString('hex')).to.equal 'fffe00015201ab'

    it 'builds a noTimeoutReset ping correctly', ->
      command = new Command 0x00, 0x01, 0, noTimeoutReset: true
      command.setSequence 0x52
      expect(command.buffer.toString('hex')).to.equal 'fffd00015201ab'

    it 'builds a getUserConfig command correctly', ->
      command = new Command 0x02, 0x40, 1
      command.setDataUint8 0, 0x01
      command.setSequence 0x52
      expect(command.buffer.toString('hex')).to.equal 'ffff024052020168'

  describe '#setDataUint8', ->
    it 'works correctly', ->
      command = new Command 0xCC, 0xDD, 6
      command.buffer.fill 0
      command.setDataUint8 3, 0x42
      expect(command.buffer.toString('hex')).to.
         equal '00000000000000000042000000'

  describe '#setDataUint16', ->
    it 'works correctly', ->
      command = new Command 0xCC, 0xDD, 8
      command.buffer.fill 0
      command.setDataUint16 3, 0xAABB
      expect(command.buffer.toString('hex')).to.
         equal '000000000000000000aabb00000000'

  describe '#setDataUint32', ->
    it 'works correctly', ->
      command = new Command 0xCC, 0xDD, 8
      command.buffer.fill 0
      command.setDataUint32 3, 0xAABBEEFF
      expect(command.buffer.toString('hex')).to.
         equal '000000000000000000aabbeeff0000'

  describe '#setDataString', ->
    it 'works correctly', ->
      command = new Command 0xCC, 0xDD, 8
      command.buffer.fill 0
      command.setDataString 3, 'Hello'
      expect(command.buffer.toString('hex')).to.
         equal '00000000000000000048656c6c6f00'

  describe '#setDataBytes', ->
    it 'works correctly', ->
      command = new Command 0xCC, 0xDD, 8
      command.buffer.fill 0
      command.setDataBytes 3, new Buffer([0xAA, 0xBB, 0xEE])
      expect(command.buffer.toString('hex')).to.
         equal '000000000000000000aabbee000000'

