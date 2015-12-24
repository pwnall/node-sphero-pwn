serialport = require 'serialport'

# Communication channel with a robot over a Bluetooth serial port (RFCONN).
class SerialChannel
  # Creates a communication channel with a robot.
  #
  # @param {String} rfconnPath the path to the device file connecting to the
  #   robot's Bluetooth RFCONN service
  # @param {Hash} options
  # @option options {Number} baudRate 115200 by default
  constructor: (serialPath, options) ->
    @sourceId = "serial://#{serialPath}"
    options ||= {}
    baudRate = options.baudRate || 115200

    @_port = new serialport.SerialPort serialPath,
        { baudRate: baudRate, dataBits: 8, stopBits: 1,
        parser: serialport.parsers.raw }, false
    @_openPromise = null
    @_closePromise = null

  # Opens the communication channel to the robot.
  #
  # The channel is automatically opened when a write is attempted.
  #
  # @return {Promise<Boolean>} resolved with true when the channel is opened
  open: ->
    @_openPromise ||= new Promise (resolve, reject) =>
      @_port.open  (error) =>
        if error
          reject error
          return
        @_port.on 'error', @_onError.bind(@)
        @_port.on 'data', (data) =>
          @onData data
        @_port.on 'close', @_onClose.bind(@)
        resolve true

  # Queues up some binary data to be sent to the robot.
  #
  # @param {Buffer} data the bytes to be sent to the robot over the RFCONN port
  # @return {Promise<Boolean>} resolves to true once the data is written
  write: (data) ->
    @open()
      .then =>
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
    @open()
      .then =>
        @_portClosePromise ||= new Promise (resolve, reject) =>
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
  onError: (error) ->
    return

  # @return {String} a unique identifier for this channel's source
  sourceId: null

  # Opens the serial port.
  #
  # @return {Promise<Boolean>} resolved with true when the serial port is open
  _openPort: ->

  # Called when an error occurs.
  #
  # @param {Error} error the error that occured
  _onError: (error) ->
    @onError error

  # Called when a communication channel is closed.
  _onClose: ->
    return


module.exports = SerialChannel
