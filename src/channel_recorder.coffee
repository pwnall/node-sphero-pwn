fs = require 'fs-promise'

Recording = require './recording.coffee'

# Records all the bytes going to a channel.
class ChannelRecorder
  # @param {SerialChannel} the channel being recorded
  # @param {String} recordingPath the file where the recording will be saved
  constructor: (channel, recordingPath) ->
    @sourceId = channel.sourceId
    @_channel = channel
    @_channel.onData = @_onChannelData.bind(@)
    @_recordingPath = recordingPath
    @_openPromise = null
    @_fd = null

  # @see {SerialChannel#onError}
  onError: (error) ->
    return

  # @see {SerialChannel#onData}
  onData: (data) ->
    return

  # @see {SerialChannel#sourceId}
  sourceId: null

  # @see {SerialChannel#open}
  open: ->
    @_openPromise ||= fs.open(@_recordingPath, 'w')
      .then (fd) =>
        @_fd = fd
        @_channel.open()

  # @see {SerialChannel#write}
  write: (data) ->
    @open()
      .then =>
        lineString = "> " + Recording.bufferToHex(data) + "\n"
        fs.writeSync @_fd, lineString, 'utf8'
        fs.fsyncSync @_fd
        @_channel.write data

  # @see {SerialChannel#close}
  close: ->
    @open()
      .then =>
        @_channel.close()
      .then =>
        fs.closeSync @_fd unless @_fd is null
        @_fd = null

  _onChannelData: (data) ->
    @open()
      .then =>
        lineString = "< " + Recording.bufferToHex(data) + "\n"
        fs.writeSync @_fd, lineString, 'utf8'
        fs.fsyncSync @_fd
        @onData data


module.exports = ChannelRecorder
