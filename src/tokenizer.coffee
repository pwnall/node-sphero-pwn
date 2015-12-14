# The tokenizer is a finite state machine that consumes characters and
# transitions between the states below.

START_OF_PACKET = 0  # Looking for the start-of-packet byte, 0xFF
PACKET_TYPE = 1  # Reading the packet type
RESPONSE_CODE = 2  # Reading the response code byte
RESPONSE_SEQUENCE = 3  # Reading the response sequence byte
RESPONSE_DATA_LENGTH = 4  # Reading the response data length
RESPONSE_DATA = 5  # Reading response data bytes
RESPONSE_CHECKSUM = 6  # Reading the response checksum
ASYNC_ID_CODE = 7  # Reading the async message ID code (type)
ASYNC_DATA_LENGTH_MSB = 8  # Reading the MSB of the async message's data length
ASYNC_DATA_LENGTH_LSB = 9  # Reading the LSB of the async message's data length
ASYNC_DATA = 10  # Reading async message data bytes
ASYNC_CHECKSUM = 11  # Reading the async message's checksum


# Splits incoming data bytes into packets.
#
# This does not implement the EventEmitter interface because the tokenizer is
# expected to have a single object (a Session instance) listening to all its
# events.
module.exports = class Tokenizer
  # Creates a tokenizer with no stored data.
  constructor: ->
    @_state = START_OF_PACKET

    # The response code or async message ID code.
    @_code = null
    @_sequence = null
    @_dataLeft = null
    @_dataOffset = null
    @_data = null
    @_checksum = 0

  # Called when a data stream error is encountered.
  #
  # @param {Error} error the error that was encountered, with a descriptive
  #   message
  onError: (error) ->
    return

  # Called when a byte is encountered outside a binary packet.
  #
  # This should only happen when the robot's shell is used. Returned characters
  # should be displayed to the user as they are.
  #
  # @param {String} char a one-character string
  onText: (char) ->
    return

  # Called when a command response is decoded from the stream.
  #
  # @param {Response} response a fully decoded response
  onResponse: (response) ->
    return

  # Called when an asynchronous message is decoded from the stream.
  #
  # @param {Async} a fully decoded asynchronous message
  onAsync: (async) ->
    return

  # Tokenizes a new chunk of data.
  #
  # @param {Buffer} data the chunk of data to be tokenized
  consume: (data) ->
    i = 0
    while i < data.length
      byte = data[i]
      i += 1

      switch @_state
        # Packet header.
        when START_OF_PACKET
          if byte is 0xFF
            @_state = PACKET_TYPE
          else
            @onText String.fromCharCode(byte)
        when PACKET_TYPE
          @_checksum = 0
          if byte is 0xFF
            @_state = RESPONSE_CODE
          else if byte is 0xFE
            @_state = ASYNC_ID_CODE
          else
            @_state = START_OF_PACKET
            @onError new Error("Invalid packet type #{byte}")

        # Response header.
        when RESPONSE_CODE
          @_checksum = (@_checksum + byte) & 0xFF
          @_code = byte
          @_state = RESPONSE_SEQUENCE
        when RESPONSE_SEQUENCE
          @_checksum = (@_checksum + byte) & 0xFF
          @_sequence = byte
          @_state = RESPONSE_DATA_LENGTH
        when RESPONSE_DATA_LENGTH
          @_checksum = (@_checksum + byte) & 0xFF
          @_newDataBuffer byte - 1
          @_state = RESPONSE_DATA
          @_checkDoneReadingData()

        # Async message header.
        when ASYNC_ID_CODE
          @_checksum = (@_checksum + byte) & 0xFF
          @_code = byte
          @_state = ASYNC_DATA_LENGTH_MSB
        when ASYNC_DATA_LENGTH_MSB
          @_checksum = (@_checksum + byte) & 0xFF
          @_dataLeft = (byte << 8)
          @_state = ASYNC_DATA_LENGTH_LSB
        when ASYNC_DATA_LENGTH_LSB
          @_checksum = (@_checksum + byte) & 0xFF
          @_newDataBuffer((@_dataLeft | byte) - 1)
          @_state = ASYNC_DATA
          @_checkDoneReadingData()

        # Data.
        when RESPONSE_DATA, ASYNC_DATA
          # TODO(pwnall): This can be optimized by grabbing all the data left
          #               in the buffer at once.
          @_checksum = (@_checksum + byte) & 0xFF
          @_data[@_dataOffset] = byte
          @_dataOffset += 1
          @_dataLeft -= 1
          @_checkDoneReadingData()

        # Response checksum and construction.
        when RESPONSE_CHECKSUM
          expected = @_checksum ^ 0xFF
          if expected != byte
            @onError new Error(
                "Invalid response checksum #{byte}, expected #{expected}")
          else
            response =
              code: @_code, sequence: @_sequence, data: @_data
            @onResponse response
          @_state = START_OF_PACKET
          @_data = null
          @_dataLeft = null

        # Async message checksum and construction.
        when ASYNC_CHECKSUM
          expected = @_checksum ^ 0xFF
          if expected != byte
            @onError new Error(
                "Invalid async message checksum #{byte}, expected #{expected}")
          else
            async =
              idCode: @_code, data: @_data
            @onAsync async
          @_state = START_OF_PACKET
          @_data = null
          @_dataLeft = null

  # Create a new data buffer for a response or async message.
  #
  # @param {Number} dataSize the number of data bytes expected
  _newDataBuffer: (dataSize) ->
    @_data = new Uint8Array dataSize
    @_dataLeft = dataSize
    @_dataOffset = 0
    return

  # Transition the FSM to the next state if we're done reading all the data.
  _checkDoneReadingData: ->
    return unless @_dataLeft is 0
    if @_state == RESPONSE_DATA
      @_state = RESPONSE_CHECKSUM
    else
      @_state = ASYNC_CHECKSUM
    return
