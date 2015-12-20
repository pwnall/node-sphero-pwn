Recording = require './recording.coffee'

fs = require 'fs-promise'

# Implements the Channel API using data from a file.
class ReplayChannel
  # Creates a channel that replays operations previously recorded to a file.
  #
  # @param {String} recordingPath the file holding the recording to be replayed
  constructor: (recordingPath) ->
    @_recordingPath = recordingPath
    @_dataPromise = null
    @_recording = null
    @_index = 0
    @_readRecording()
      .then =>
        @_drainReads()

  # @see {Channel#write}
  write: (data) ->
    @_readRecording()
      .then =>
        @_drainReads()
      .then =>
        if @_recording.code(@_index) isnt '>'
          throw new Error("Unexpected write")
        expectedData = @_recording.data @_index
        @_index += 1
        if data.compare(expectedData) isnt 0
          expected = Recording.bufferToHex expectedData
          got = Recording.bufferToHex data
          throw new Error("Invalid data; expected #{expected}; got #{got}")

        # NOTE: Draining reads should not block the resolution of the write
        #       promise. However, we can't just wait until the next write
        #       occurs.
        @_drainReads()

        true

  # @see {Channel#onData}
  onData: (data) ->
    return

  # @see {Channel#onError}
  onError: (error) ->
    return

  # @see {Channel#close}
  close: ->
    @_readRecording()
      .then =>
        @_drainReads()
      .then =>
        opsLeft = @_recording.length - @_index
        if opsLeft isnt 0
          throw new Error("Closed before performing #{opsLeft} remaining ops")

  # @return {Promise<Boolean>} resolved to true when the recording file is
  #   read into memory
  _readRecording: ->
    @_dataPromise ||= fs.readFile(@_recordingPath, encoding: 'utf8')
      .then (data) =>
        @_recording = new Recording data

  # @return {Promise<Boolean>} resolved to true when the next operation is a
  #   write or there is no operation left
  _drainReads: ->
    if @_recording.code(@_index) isnt '<'
      return Promise.resolve true

    new Promise (resolve, reject) =>
      data = @_recording.data @_index
      @_index += 1
      try
        @onData data
      catch onDataError
        reject onDataError
        return
      resolve @_drainReads()


module.exports = ReplayChannel
