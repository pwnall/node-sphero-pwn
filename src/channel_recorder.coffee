fs = require 'fs'

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
    null

  # @see {Channel#write}
  write: (data) ->
    @_openFile()
      .then (fd) ->
        new Promise (resolve, reject) ->
          fs.write fd, string, (error) ->
            if error
              reject error
              return
            fs.fsync fd, (error) ->
              if error
                reject error
                return
              resolve true
      .then =>
        @_channel.write "> " + Recording.bufferToHex(@data) + "\n"

  # @see {Channel#close}
  close: ->
    @_openFile()
      .then (fd) ->
        fs.close (error) ->
          if error
            @_onError error
            return
          @_channel.close()

  _onChannelData: (data) ->

  # @return {Promise<Integer>} resolved when the file is open, with a file
  #   descriptor
  _openFile: ->
    @_openPromise ||= new Promise (resolve, reject) ->
      fs.open @_recordingPath, 'w', (error, fd) ->
        if error
          reject error
        else
          resolve fd



module.exports = ChannelRecorder
