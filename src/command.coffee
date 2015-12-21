# Buffer holding a command that will be sent to the robot.
class Command
  # @return {Buffer} the underlying Buffer
  buffer: null

  # Creates a buffer for a command.
  #
  # The command's buffer must be finalized by calling {Command#setSequence}
  # before it is transmitted to the robot.
  #
  # @param {Number} deviceId the ID of the virtual device that receives the
  #   command
  # @param {Number} commandId the ID of the command within the virtual device
  # @param {Number} dataLength the number of extra bytes in the command
  # @param {Object?} flags (optional) flags that apply to all commands
  # @option flags {Boolean} noResponse if true, the robot will be instructed
  #   not to provide a response to the command
  # @option flags {Boolean} noTimeoutReset if true, sending this command will
  #   not reset the client interactivity timeout
  constructor: (deviceId, commandId, dataLength, flags) ->
    @_dataLength = dataLength
    @buffer = new Buffer 7 + @_dataLength
    @buffer[0] = 0xFF
    @buffer[2] = deviceId
    @buffer[3] = commandId
    @buffer[5] = if dataLength > 254 then 0xFF else dataLength + 1

    sop2 = 0xFF
    if flags
      if flags.noResponse
        sop2 &= 0xFE
      if flags.noTimeoutReset
        sop2 &= 0xFD
    @buffer[1] = sop2

  # Sets the sequence number and checksum bytes in the command buffer.
  #
  # After this method is called, the buffer can be transmitted to the robot.
  #
  # @param {Number} sequence the sequence number to be set
  # @return {Command} this
  setSequence: (sequence) ->
    @buffer[4] = sequence
    @buffer[6 + @_dataLength] = Command.checksum @buffer, 2, 6 + @_dataLength
    @

  # Sets a byte in the data buffer.
  #
  # @param {Number} offset the byte's offset in the data field of the command
  #   buffer
  # @param {Number} value the byte value to set
  # @return {Command} this
  setDataUint8: (offset, value) ->
    @buffer.writeUInt8 value, offset + 6
    @

  # Computes the checksum over a range of bytes in a buffer
  #
  # @param {Buffer} buffer
  # @param {Number} start the index of the first byte in the buffer whose
  #   checksum will be computed
  # @param {Number} end one past the index of the last byte in the buffer whose
  #   checksum will be computed
  # @return {Number} the computed checksum
  @checksum: (buffer, start, end) ->
    sum = 0
    while start < end
      sum = (sum + buffer[start]) & 0xFF
      start += 1
    sum ^ 0xFF


module.exports = Command
