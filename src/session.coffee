Tokenizer = require './tokenizer.coffee'

EventEmitter = require 'events'

# Command-level API over a communication channel with a robot.
class Session extends EventEmitter
  constructor: (channel) ->
    @_channel = channel
    @_channel.onData = @_onChannelData.bind(@)
    @_channel.onError = @_onChannelError.bind(@)
    @_channel.onClose = @_onChannelClose.bind(@)

    @_tokenizer = new Tokenizer
    @_tokenizer.onResponse = @_onTokenizerResponse.bind(@)
    @_tokenizer.onAsync = @_onTokenizerAsync.bind(@)

    @_lastSequence = 0
    @_resolves = new Array 256
    @_resolves[i] = null for i in [0...256]


  # Sends a command to the robot and receives its response.
  #
  # @param {Command} command the command to be sent to the robot; the command
  #   will receive a sequence number and have its checksum recomputed
  # @return {Promise<Object>} resolved with an obect that describes the
  #   command's response;
  sendCommand: (command) ->
    new Promise (resolve, reject) =>
      while true
        @_lastSequence = (@_lastSequence + 1) & 0xFF
        break unless @_resolves[@_lastSequence]
      @_resolves[@_lastSequence] = resolve

      command.setSequence @_lastSequence
      @_channel.write(command.buffer).catch (error) =>
        @_resolves[@_lastSequence] = null
        reject error

  # Closes the communication channel used by the session.
  #
  # @return {Promise} resolved when the channel is closed
  close: ->
    @_channel.close()

  # @see {Tokenizer#onResponse}
  _onTokenizerResponse: (response) ->
    sequence = response.sequence
    if resolve = @_resolves[sequence]
      @_resolves[sequence] = null
      resolve response
    else
      @emit 'error', new Error(
          "Received response with unknown sequence #{sequence}")

  # @see {Tokenizer#onAsync}
  _onTokenizerAsync: (async) ->
    @emit 'async', async

  # @see {Channel#onData}
  _onChannelData: (data) ->
    @_tokenizer.consume data

  # @see {Channel#error}
  _onChannelError: (error) ->
    @emit 'error', error

  # @see {Channel#close}
  _onChannelClose: ->
    return


module.exports = Session
