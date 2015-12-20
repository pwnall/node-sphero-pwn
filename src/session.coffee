EventEmitter = require 'events'

# Command-level API over a communication channel with a robot.
class Session extends EventEmitter
  constructor: (channel) ->
    @_channel = channel
    @_tokenizer = Tokenizer.new
    @_tokenizer.onResponse = @_onTokenizerResponse.bind(@)
    @_tokenizer.onAsync = @_onTokenizerAsync.bind(@)


  # @see {Tokenizer#onResponse}
  @_onTokenizerResponse: (response) ->
    null

  # @see {Tokenizer#onAsync}
  @_onTokenizerAsync: (async) ->
    @emit async
