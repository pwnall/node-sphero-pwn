Recording = SpheroPwn.Recording

describe 'Recording', ->
  describe '.bufferFromHex', ->
    it 'works on empty data', ->
      expect(Recording.bufferFromHex('').toString('hex')).to.equal ''

    it 'works with one byte', ->
      expect(Recording.bufferFromHex('2A').toString('hex')).to.equal '2a'

    it 'works with one-nibble bytes', ->
      expect(Recording.bufferFromHex('02 03 05 0B').toString('hex')).to.
          equal '0203050b'

    it 'works with two-nibble bytes', ->
      expect(Recording.bufferFromHex('10 11 20 21 FE FF').
          toString('hex')).to.equal '10112021feff'

    it 'has the digits down correctly', ->
      expect(Recording.bufferFromHex(
          '00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F').toString('hex')).
          to.equal '000102030405060708090a0b0c0d0e0f'

  describe '.bufferToHex', ->
    it 'works on empty data', ->
      expect(Recording.bufferToHex(new Buffer([]))).to.equal ''

    it 'works with one byte', ->
      expect(Recording.bufferToHex(new Buffer([42]))).to.equal '2A'

    it 'works with one-nibble bytes', ->
      expect(Recording.bufferToHex(new Buffer([2, 3, 5, 11]))).to.
          equal '02 03 05 0B'

    it 'works with two-nibble bytes', ->
      expect(Recording.bufferToHex(new Buffer([16, 17, 32, 33, 254, 255]))).
          to.equal '10 11 20 21 FE FF'

    it 'has the digits down correctly', ->
      expect(Recording.bufferToHex(new Buffer([0...16]))).to.
          equal '00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F'

  describe '#constructor', ->
    it 'works on an empty recording', ->
      recording = new Recording ''
      expect(recording).to.have.property 'length', 0
      expect(recording.code(0)).to.equal null
      expect(recording.data(0)).to.equal null

    it 'works on a one-line write recording', ->
      recording = new Recording "> 48 65 6C 6C 6F\n"
      expect(recording).to.have.property 'length', 1
      expect(recording.code(0)).to.equal '>'
      expect(recording.data(0)).to.deep.equal new Buffer('Hello')

    it 'works on a one-line read recording', ->
      recording = new Recording "< 77 6F 72 6C 64\n"
      expect(recording).to.have.property 'length', 1
      expect(recording.code(0)).to.equal '<'
      expect(recording.data(0)).to.deep.equal new Buffer('world')

    it 'works on a three-line mixed recording', ->
      recording = new Recording '''
> 48 65 6C 6C 6F
< 77 6F 72 6C 64
> 62 61 69
'''
      expect(recording).to.have.property 'length', 3
      expect(recording.code(0)).to.equal '>'
      expect(recording.data(0)).to.deep.equal new Buffer('Hello')
      expect(recording.code(1)).to.equal '<'
      expect(recording.data(1)).to.deep.equal new Buffer('world')
      expect(recording.code(2)).to.equal '>'
      expect(recording.data(2)).to.deep.equal new Buffer('bai')
