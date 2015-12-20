fs = require 'fs-promise'

Recording = require './recording.coffee'

# Records all the bytes going to a channel.
class ChannelRecorder
  # @param {Channel} the channel being recorded
  # @param {String} recordingPath the file where the recording will be saved
  constructor: (channel, recordingPath) ->
    @_channel = channel
    @_channel.onData = @_onChannelData.bind(@)
    @_recordingPath = recordingPath
    @_openPromise = null
    @_fd = null

  # @see {Channel#onError}
  onError: (error) ->
    return

  # @see {Channel#onData}
  onData: (data) ->
    return

  # @see {Channel#write}
  write: (data) ->
    @_openFile()
      .then =>
        lineString = "> " + Recording.bufferToHex(data) + "\n"
        fs.writeSync @_fd, lineString, 'utf8'
        fs.fsyncSync @_fd
        @_channel.write data

  # @see {Channel#close}
  close: ->
    @_openFile()
      .then =>
        @_channel.close()
      .then =>
        fs.closeSync @_fd unless @_fd is null
        @_fd = null

  _onChannelData: (data) ->
    @_openFile()
      .then =>
        lineString = "< " + Recording.bufferToHex(data) + "\n"
        fs.writeSync @_fd, lineString, 'utf8'
        fs.fsyncSync @_fd
        @onData data

  # @return {Promise} resolved when the file is open
  _openFile: ->
    @_openPromise ||= fs.open(@_recordingPath, 'w')
      .then (fd) =>
        @_fd = fd


module.exports = ChannelRecorder
