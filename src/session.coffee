Tokenizer = require './tokenizer.coffee'

# Command-level API over a communication channel with a robot.
#
# This is higher-level than the message-level API provided by {Channel}, but
# lower-level than the {Robot} API.
class Session
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
    @_asyncResolves = {}


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

  # Sends a command to the robot and receives its response and a notice.
  #
  # Some Sphero commands receive asynchronous messages, because the returned
  # data is too large to fit into the response data structure. This pattern is
  # common enough that it's worth coding to it.
  #
  # @param {Command} command the command to be sent to the robot; the command
  #   will receive a sequence number and have its checksum recomputed
  # @param {Number} asyncIdCode the ID code of the asynchronous message that
  #   responds to this command
  # @return {Promise<Object>} resolved with an obect that describes the
  #   command's response;
  sendAsyncCommand: (command, asyncIdCode) ->
    new Promise (resolve, reject) =>
      if @_asyncResolves[asyncIdCode]
        reject new Error(
            "Already waiting for async message with ID #{asyncIdCode}")
        return
      @_asyncResolves[asyncIdCode] = resolve



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
          "Received response message with unknown sequence #{sequence}")

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
