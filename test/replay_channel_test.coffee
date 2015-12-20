ReplayChannel = SpheroPwn.ReplayChannel

describe 'ReplayChannel', ->
  describe 'with a 1-write recording', ->
    beforeEach ->
      @channel = new ReplayChannel testRecordingPath('replay-1write')

    it 'accepts a correct write', ->
      @channel.write(new Buffer('Hello'))
        .then =>
          @channel.close()

    it 'rejects an incorrect write', ->
      @channel.write(new Buffer('world'))
        .then =>
          expect(false).to.equal 'write promise not rejected'
        .catch (error) =>
          expect(error).to.be.an.instanceOf Error
          expect(error).to.have.property 'message',
              'Invalid data; expected 48 65 6C 6C 6F; got 77 6F 72 6C 64'

    it 'rejects an unexpected close', ->
      @channel.close()
        .then =>
          expect(false).to.equal 'close promise not rejected'
        .catch (error) =>
          expect(error).to.be.an.instanceOf Error
          expect(error).to.have.property 'message',
              'Closed before performing 1 remaining ops'

  describe 'with a 1-read recording', ->
    beforeEach ->
      @channel = new ReplayChannel testRecordingPath('replay-1read')
      @buffers = []
      @channel.onData = (data) => @buffers.push data

    it 'reports the read data before closing', ->
      @channel.close()
        .then =>
          expect(@buffers.length).to.equal 1
          expect(@buffers[0]).to.deep.equal new Buffer('world')

    it 'reports the data before the close call is issued', ->
      (new Promise (resolve, reject) =>
        @channel = new ReplayChannel testRecordingPath('replay-1read')
        @channel.onData = (data) => resolve data
      ).then (data) =>
        expect(data).to.deep.equal new Buffer('world')
        @channel.close()

  describe 'with a write-read-write-read recording', ->
    beforeEach ->
      @channel = new ReplayChannel testRecordingPath('replay-wrwr')

    it 'rejects an immediate close', ->
      @channel.close()
        .then =>
          expect(false).to.equal 'close promise not rejected'
        .catch (error) =>
          expect(error).to.be.an.instanceOf Error
          expect(error).to.have.property 'message',
              'Closed before performing 4 remaining ops'

    it 'rejects a first incorrect write', ->
      @channel.write(new Buffer('world'))
        .then =>
          expect(false).to.equal 'write promise not rejected'
        .catch (error) =>
          expect(error).to.be.an.instanceOf Error
          expect(error).to.have.property 'message',
              'Invalid data; expected 48 65 6C 6C 6F; got 77 6F 72 6C 64'

    it 'reports a read right after the write', ->
      (new Promise (resolve, reject) =>
        @channel.onData = (data) => resolve data
        @channel.write(new Buffer('Hello')).catch (error) => reject error
      ).then (data) =>
        expect(data).to.deep.equal new Buffer('world')

    it 'rejects a close after the first write', ->
      @channel.write(new Buffer('Hello'))
        .then =>
          @channel.close()
        .then =>
          expect(false).to.equal 'close promise not rejected'
        .catch (error) =>
          expect(error).to.be.an.instanceOf Error
          expect(error).to.have.property 'message',
              'Closed before performing 2 remaining ops'

    it 'rejects a second incorrect write', ->
      @channel.write(new Buffer('Hello'))
        .then =>
          @channel.write(new Buffer('bai'))
        .then =>
          expect(false).to.equal 'write promise not rejected'
        .catch (error) =>
          expect(error).to.be.an.instanceOf Error
          expect(error).to.have.property 'message',
              'Invalid data; expected 68 61 69; got 62 61 69'

    it 'reports reads right after writes', ->
      (new Promise (resolve, reject) =>
        @channel.onData = (data) => resolve data
        @channel.write(new Buffer('Hello')).catch (error) => reject error
      ).then (data) =>
        expect(data).to.deep.equal new Buffer('world')
        new Promise (resolve, reject) =>
          @channel.onData = (data) => resolve data
          @channel.write(new Buffer('hai')).catch (error) => reject error
       .then (data) =>
        expect(data).to.deep.equal new Buffer('bai')
        @channel.close()

  describe 'with a write-read-read-write-read-read recording', ->
    beforeEach ->
      @channel = new ReplayChannel testRecordingPath('replay-wrrwrr')

    it 'reports reads right after writes', ->
      (new Promise (resolve, reject) =>
        reads = []
        @channel.onData = (data) =>
          reads.push data
          resolve reads if reads.length is 2
        @channel.write(new Buffer('Hello')).catch (error) => reject error
      ).then (data) =>
        expect(data).to.deep.equal [new Buffer('world'), new Buffer('bai')]
        new Promise (resolve, reject) =>
          reads = []
          @channel.onData = (data) =>
            reads.push data
            resolve reads if reads.length is 2
          @channel.write(new Buffer('hai')).catch (error) => reject error
       .then (data) =>
        expect(data).to.deep.equal [new Buffer('iab'), new Buffer('owrld')]
        @channel.close()
