ChannelRecorder = SpheroPwn.ChannelRecorder
ReplayChannel = SpheroPwn.ReplayChannel

fs = require 'fs-promise'
temp = require('temp').track()

describe 'ChannelRecorder', ->
  beforeEach (done) ->
    temp.open 'recorder-', (error, info) =>
      throw error if error
      @path = info.path
      fs.close(info.fd)
        .then ->
          done()

  afterEach (done) ->
    temp.cleanup (error, stats) ->
      throw error if error
      done()

  it 'records a write correctly', ->
    @channel = new ReplayChannel testRecordingPath('synthetic-1write')
    @recorder = new ChannelRecorder @channel, @path
    @recorder.open()
      .then =>
        @recorder.write(new Buffer('Hello'))
      .then =>
        @recorder.close()
      .then =>
        fs.readFile @path, 'utf8'
      .then (recording) =>
        @recording = recording
        fs.readFile testRecordingPath('synthetic-1write'), 'utf8'
      .then (goldenRecording) =>
        expect(@recording).to.equal goldenRecording

  it 'reports a read correctly', ->
    (new Promise (resolve, reject) =>
      @channel = new ReplayChannel testRecordingPath('synthetic-1read')
      @recorder = new ChannelRecorder @channel, @path
      @recorder.onData = (data) => resolve data
      @recorder.open()
    ).then (data) =>
      expect(data).to.deep.equal new Buffer('world')
      @recorder.close()
     .then =>
      fs.readFile @path, 'utf8'
     .then (recording) =>
      @recording = recording
      fs.readFile testRecordingPath('synthetic-1read'), 'utf8'
     .then (goldenRecording) =>
      expect(@recording).to.equal goldenRecording

  it 'reports a write-read-write-read correctly', ->
    @channel = new ReplayChannel testRecordingPath('synthetic-wrwr')
    @recorder = new ChannelRecorder @channel, @path
    @recorder.open()
      .then =>
        new Promise (resolve, reject) =>
          @recorder.onData = (data) => resolve data
          @recorder.write(new Buffer('Hello')).catch (error) => reject error
      .then (data) =>
        expect(data).to.deep.equal new Buffer('world')
        new Promise (resolve, reject) =>
          @recorder.onData = (data) => resolve data
          @recorder.write(new Buffer('hai')).catch (error) => reject error
      .then (data) =>
        expect(data).to.deep.equal new Buffer('bai')
        @recorder.close()
      .then =>
        fs.readFile @path, 'utf8'
      .then (recording) =>
        @recording = recording
        fs.readFile testRecordingPath('synthetic-wrwr'), 'utf8'
      .then (goldenRecording) =>
        expect(@recording).to.equal goldenRecording
