serialport = require 'serialport'

# Communication channel with a robot.
#
# This is a light abstraction over the Bluetooth serial port (RFCONN) used to
# talk to a robot.
class Channel
  # Opens up a communication channel with a robot.
  #
  # @param {String} rfconnPath the path to the device file connecting to the
  #   robot's Bluetooth RFCONN service
  # @param {Hash} options
  constructor: (serialPath, options) ->
    options ||= {}
    baudRate = options.baudRate || 115200

    @_port = new serialport.SerialPort serialPath,
        { baudRate: baudRate, dataBits: 8, stopBits: 1,
        parser: serialport.parsers.raw }
    @_port.on 'error', @_onError.bind(@)
    @_port.on 'data', (data) => @onData data
    @_port.on 'close', @_onClose.bind(@)

  # Queues up some binary data to be sent to the robot.
  #
  # @param {Buffer} data the bytes to be sent to the robot over the RFCONN port
  # @return {Promise<Boolean>} resolves to true once the data is written
  write: (data) ->
    new Promise (resolve, reject) =>
      @_port.write data, (error) =>
        if error
          reject error
          return
        @_port.drain (error) =>
          if error
            reject error
            return
          resolve true

  # Closes the underlying communication channel.
  #
  # @return {Promise<Boolean>} resolved with true when the channel is closed
  close: ->
    new Promise (resolve, reject) =>
      @_port.close (error) =>
        if error
          reject error
        else
          resolve true

  # Called when data is received from the robot.
  #
  # @param {Buffer} data the received data bytes
  onData: (data) ->
    return

  # Called when an error occurs.
  #
  # @param {Error} error the error that occured
  _onError: (error) ->
    @onError error


module.exports = Channel
