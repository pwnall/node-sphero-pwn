Tokenizer = SpheroPwn.Tokenizer

describe 'Tokenizer', ->
  beforeEach ->
    @tokenizer = new Tokenizer()
    @events = []
    @tokenizer.onError = (error) =>
      @events.push error: error.message
    @tokenizer.onResponse = (response) =>
      @events.push response: response
    @tokenizer.onAsync = (async) =>
      @events.push async: async
    @tokenizer.onText = (char) =>
      @events.push text: char

  it 'parses an echo response', ->
    @tokenizer.consume [0xFF, 0xFF, 0x52, 0x01, 0x01, 0xAB]
    expect(@events.length).to.equal 1
    expect(@events[0]).to.have.property 'response'
    expect(@events[0].response).to.have.property 'code', 0x52
    expect(@events[0].response).to.have.property 'sequence', 0x01
    expect(@events[0].response).to.have.property 'data'
    expect(@events[0].response.data).to.be.instanceOf Uint8Array
    expect(@events[0].response.data.length).to.equal 0

  it 'parses a get version response', ->
    @tokenizer.consume [0xFF, 0xFF, 0x52, 0x01, 0x09, 0x01, 0x03, 0x01, 0x00,
        0x00, 0x33, 0x00, 0x00, 0x6B]
    expect(@events.length).to.equal 1
    expect(@events[0]).to.have.property 'response'
    expect(@events[0].response).to.have.property 'code', 0x52
    expect(@events[0].response).to.have.property 'sequence', 0x01
    expect(@events[0].response).to.have.property 'data'
    expect(@events[0].response.data).to.be.instanceOf Uint8Array
    expect(@events[0].response.data.length).to.equal 8
    expect(Array.from(@events[0].response.data)).to.deep.equal(
        [0x01, 0x03, 0x01, 0x00, 0x00, 0x33, 0x00, 0x00])

  it 'bounces an echo response with a bad checksum', ->
    @tokenizer.consume [0xFF, 0xFF, 0x52, 0x01, 0x01, 0xAC]
    expect(@events).to.deep.equal([{
        error: 'Invalid response checksum 172, expected 171' }])

  it 'bounces a get version response with a bad checksum', ->
    @tokenizer.consume [0xFF, 0xFF, 0x52, 0x01, 0x09, 0x01, 0x03, 0x01, 0x00,
        0x00, 0x33, 0x00, 0x00, 0xCC]
    expect(@events).to.deep.equal([
        { error: 'Invalid response checksum 204, expected 107' }])

  it 'parses an empty async message', ->
    @tokenizer.consume [0xFF, 0xFE, 0x02, 0x00, 0x01, 0xFC]
    expect(@events.length).to.equal 1
    expect(@events[0]).to.have.property 'async'
    expect(@events[0].async).to.have.property 'idCode', 0x02
    expect(@events[0].async.data).to.be.instanceOf Uint8Array
    expect(@events[0].async.data.length).to.equal 0

  it 'parses a large async message', ->
    data = (i % 256 for i in [1..632])
    @tokenizer.consume [].concat([0xFF, 0xFE, 0x04, 0x02, 0x79], data, [0x24])
    expect(@events.length).to.equal 1
    expect(@events[0]).to.have.property 'async'
    expect(@events[0].async).to.have.property 'idCode', 0x04
    expect(@events[0].async.data).to.be.instanceOf Uint8Array
    expect(@events[0].async.data.length).to.equal 632
    expect(Array.from(@events[0].async.data)).to.deep.equal(data)

  it 'parses an echo response surrounded by text', ->
    @tokenizer.consume [0x41, 0xFF, 0xFF, 0x52, 0x01, 0x01, 0xAB, 0x5A]
    expect(@events.length).to.equal 3
    expect(@events[0]).to.deep.equal text: 'A'
    expect(@events[1]).to.have.property 'response'
    expect(@events[1].response).to.have.property 'code', 0x52
    expect(@events[1].response).to.have.property 'sequence', 0x01
    expect(@events[1].response).to.have.property 'data'
    expect(@events[1].response.data).to.be.instanceOf Uint8Array
    expect(@events[1].response.data.length).to.equal 0
    expect(@events[2]).to.deep.equal text: 'Z'

  it 'parses an empty async surrounded by text', ->
    @tokenizer.consume [0x41, 0xFF, 0xFE, 0x02, 0x00, 0x01, 0xFC, 0x5A]
    expect(@events.length).to.equal 3
    expect(@events[0]).to.deep.equal text: 'A'
    expect(@events[1]).to.have.property 'async'
    expect(@events[1].async).to.have.property 'idCode', 0x02
    expect(@events[1].async.data).to.be.instanceOf Uint8Array
    expect(@events[1].async.data.length).to.equal 0
    expect(@events[2]).to.deep.equal text: 'Z'
