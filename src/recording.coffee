# A recorded set of operations.
class Recording
  # Parses a serialized recording.
  #
  # @param {String} string the serialized recording; this is the content of a
  #   file written by {ChannelRecorder}
  constructor: (string) ->
    @_ops = []
    for line in string.split("\n")
      continue if line.length is 0
      op =
          code: line[0]
          data: Recording.bufferFromHex line.substring(2)
      @_ops.push op
    @length = @_ops.length

  # Retrieves the code for an operation.
  #
  # @param {Number} index 0-based operation index
  # @return {String} the operation code for the given operation; null if the
  #   given index number exceeds the number of operations in the recording
  code: (index) ->
    return null if @_ops.length <= index
    @_ops[index].code

  # Retrieves the data associated with an operation.
  #
  # @param {Number} index 0-based operation index
  # @return {Buffer} the data bytes associated with the given operation; null
  #   if the given index number exceeds the number of operations in the recording
  data: (index) ->
    return null if @_ops.length <= index
    @_ops[index].data

  # @return {Number} the number of operations in the recording
  length: null

  # Encodes a buffer's bytes into human-readable hex.
  #
  # @param {Buffer} data binary data to be encoded
  # @return {String} hex-encoded bytes separated by spaces
  @bufferToHex: (data) ->
    nibble = "0123456789ABCDEF"
    bytes = for byte in data
      nibble[byte >> 4] + nibble[byte & 0x0F]
    bytes.join(' ')

  # Decodes human-readable hex bytes into a Buffer.
  #
  # @param {String} string hex-encoded bytes separated by spaces
  # @return {Buffer} a buffer that contains the encoded bytes
  @bufferFromHex: (string) ->
    if string.length is 0
      bytes = []
    else
      bytes = (parseInt(byte, 16) for byte in string.split(' '))
    new Buffer bytes


module.exports = Recording
