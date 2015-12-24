Tokenizer = require './tokenizer.coffee'

# Command-level API over a communication channel with a robot.
#
# This is higher-level than the message-level API provided by {Channel}, but
# lower-level than the {Robot} API.
class Session
  constructor: (channel) ->
    @_channel = channel
    @_channel.onData = @_onChannelData.bind(@)
    @_channel.onError = (error) => @onError error
    @_channel.onClose = @_onChannelClose.bind(@)

    @_tokenizer = new Tokenizer
    @_tokenizer.onResponse = @_onTokenizerResponse.bind(@)
    @_tokenizer.onAsync = @_onTokenizerAsync.bind(@)
    @_tokenizer.onError = (error) => @onError error

    @_lastSequence = 0
    @_resolves = new Array 256
    @_resolves[i] = null for i in [0...256]
    @_rejects = new Array 256
    @_rejects[i] = null for i in [0...256]

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
      @_rejects[@_lastSequence] = reject

      command.setSequence @_lastSequence
      @_channel.write(command.buffer).catch (error) =>
        @_resolves[@_lastSequence] = null
        @_rejects[@_lastSequence] = null
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


  # Called when an error is encountered while communicating with the robot.
  #
  # @param {Error} error the error encountered
  onError: (error) ->
    return

  # @see {Tokenizer#onResponse}
  _onTokenizerResponse: (response) ->
    sequence = response.sequence
    if resolve = @_resolves[sequence]
      reject = @_rejects[sequence]
      @_resolves[sequence] = null
      @_rejects[sequence] = null

      if response.code is 0
        resolve response
      else
        code = Session._errorStringForCode response.code
        reject new Error(
            "Received Sphero command response with error code #{code}")
    else
      @onError new Error(
          "Received response message with unknown sequence #{sequence}")

  # @see {Tokenizer#onAsync}
  _onTokenizerAsync: (async) ->
    # TODO(pwnall): filter async
    @onAsync async

  # @see {Channel#onData}
  _onChannelData: (data) ->
    @_tokenizer.consume data

  # @see {Channel#close}
  _onChannelClose: ->
    return

  # Converts a Sphero command response code to a developer-friendly string.
  #
  # @param {Number} code the response code
  # @return {String} developer-friendly translation of the response code
  @_errorStringForCode: (code) ->
    @_errorCodes[code] || '(unknown code)'


  # @return {Object<Number, String>} maps response codes to error strings
  @_errorCodes = []


Session._errorCodes[0x00] = 'OK'  # Command succeeded.
Session._errorCodes[0x01] = 'Generic Error'  # General, non-specific error.
Session._errorCodes[0x02] = 'Bad Checksum'  # Received checksum failure.
Session._errorCodes[0x03] = 'Got Fragment'  # Received command fragment.
Session._errorCodes[0x04] = 'Bad Command'  # Unknown command ID.
Session._errorCodes[0x05] = 'Unsupported'  # Command currently unsupported.
Session._errorCodes[0x06] = 'Bad Message Format'  # Bad message format.
Session._errorCodes[0x07] = 'Invalid Parameter'  # Parameter value(s) invalid.
Session._errorCodes[0x08] = 'Execution Failure'  # Failed to execute command.
Session._errorCodes[0x09] = 'Bad Device ID'  # Unknown Device ID.
Session._errorCodes[0x0A] = 'RAM Busy'  # Generic RAM access needed but it is busy.
Session._errorCodes[0x0B] = 'Bad Password'  # Supplied password incorrect.
Session._errorCodes[0x31] = 'Low Battery'  # Voltage too low for reflash operation.
Session._errorCodes[0x32] = 'Bad Page Number'  # Illegal page number provided.
Session._errorCodes[0x33] = 'Flash Failure' # Page did not reprogram correctly.
Session._errorCodes[0x34] = 'Main App Corrupt'  # Main Application corrupt.
Session._errorCodes[0x35] = 'Timed Out'  # Msg state machine timed out.


module.exports = Session
