EventEmitter = require 'events'
noble = require 'noble'
serialport = require 'serialport'

BleChannel = require './ble_channel.coffee'
SerialChannel = require './serial_channel.coffee'

# Agent that discovers spheros.
class DiscoveryClass extends EventEmitter
  # Creates a new discovery agent.
  constructor: ->
    @_serialPorts = null
    @_peripherals = null
    @reset()

    @_started = false
    @_bleScanStarted = false
    noble.on 'stateChange', @_onBleStateChange.bind(@)
    noble.on 'discover', @_onBleDiscover.bind(@)
    @_powerState = noble.state

  # Starts discovering Bluetooth robots.
  #
  # @return {DiscoveryClass} this
  start: ->
    return if @_started
    @_started = true
    serialport.list @_onSerialPortList.bind(@)
    @_onBleStateChange noble.state
    @

  # Stops discovering Bluetooth robots.
  #
  # @return {DiscoveryClass} this
  stop: ->
    return if @_started is false
    @_started = false
    if @_bleScanStarted is true
      @_bleScanStarted = false
      noble.stopScanning()
    @

  # Erases the list of discovered Bluetooth devices.
  #
  # @return {DiscoveryClass} this
  reset: ->
    @_serialPorts = {}
    @_peripherals = {}
    @

  # Discovers Bluetooth robots until a desired robot shows up.
  #
  # @param {String} sourceId the source ID of the communication channel to the
  #   desired robot
  # @return {Promise<Channel>} resolved with a communication channel to the
  #   desired robot
  findChannel: (sourceId) ->
    new Promise (resolve, reject) =>
      @stop()
      @reset()
      onChannel = (channel) =>
        if channel.sourceId is sourceId
          @removeListener 'channel', onChannel
          @removeListener 'error', onError
          @stop()
          resolve channel
        else
          channel.close()
      onError = (error) =>
        @removeListener 'channel', onChannel
        @removeListener 'error', onError
        @stop()
        reject error
      @addListener 'channel', onChannel
      @addListener 'error', onError
      @start()

  # Called when the Bluetooth LE's powered on state changes.
  #
  # @param {String} newState the new Bluetooth LE power state
  _onBleStateChange: (newState) ->
    @_powerState = newState
    if newState is 'poweredOn' and @_started is true and
        @_bleScanStarted is false
      @_bleScanStarted = true
      noble.startScanning [], true, (error) =>
        if error
          @emit 'error', error

  # Called when a Bluetooth LE peripheral is found.
  #
  # @param {Peripheral} peripheral the bluetooth LE peripheral that was
  #   discovered
  _onBleDiscover: (peripheral) ->
    return unless peripheral.connectable

    uuid = peripheral.id
    return if uuid of @_peripherals
    @_peripherals[uuid] = true
    BleChannel.fromPeripheral(peripheral)
      .then (bleChannel) =>
        return if bleChannel is null
        if @_started is true
          @emit 'channel', bleChannel
        else
          bleChannel.close()
      .catch (error) =>
        @emit 'error', error

  # Called when serialport returns a list of ports.
  #
  # @param {Error} error
  # @param {Array<String>} ports list of ports
  _onSerialPortList: (error, ports) ->
    if error
      @emit 'error', error
    return unless ports and @_started is true
    for port in ports
      continue unless rfconnPath = port.comName
      @_onSerialPort rfconnPath

  # Called when a serial port is discovered.
  #
  # @param {String} rfconnPath the path to the serial port
  _onSerialPort: (rfconnPath) ->
    return if rfconnPath of @_serialPorts
    @_serialPorts[rfconnPath] = true
    @emit 'channel', new SerialChannel(rfconnPath)


module.exports = new DiscoveryClass
