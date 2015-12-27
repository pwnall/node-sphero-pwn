Command = require './command.coffee'
Session = require './session.coffee'

EventEmitter = require 'events'

# High-level API for commanding a robot.
class Robot extends EventEmitter
  # Creates a high-level wrapper for a communication channel to a robot.
  #
  # @param {Channel} channel the communication channel to a robot; the same
  #   channel should not be used to construct two instances of this class
  constructor: (channel) ->
    @_channel = channel
    @_session = new Session channel
    @_session.onAsync = @_onAsync.bind(@)
    @_session.onError = (error) => @emit 'error', error

  # Closes the underlying communication channel with the robot.
  #
  # @return {Promise<Boolean>} resolved when the communication channel is fully
  #   closed
  close: ->
    @_session.close()

  # Pings the robot, to test that the communication channel works.
  #
  # @return {Promise<Boolean>} resolved with true when the robot responds to
  #   the ping
  ping: ->
    command = new Command 0x00, 0x01, 0
    @_session.sendCommand(command).then (response) ->
      true

  # Returns the versions of the components in the robot's software stack.
  #
  # @return {Promise<Object>} resolved with the versions in the robot's
  #   software stack
  getVersions: ->
    command = new Command 0x00, 0x02, 0
    @_session.sendCommand(command).then (response) ->
      Robot._versionsFromData response.data

  # Parses software stack versions from an API response.
  #
  # @param {Buffer} data the data field in the API response
  # @return {Object} parsed version numbers
  @_versionsFromData: (data) ->
    responseVersion = data[0]
    versions = {}
    parseNibbles = (byte) ->
      major: (byte >> 4), minor: (byte & 0x0F)
    if responseVersion >= 1
      versions.model = data[1]
      versions.hardware = data[2]
      versions.spheroApp =
        version: data[3]
        revision: data[4]
      versions.bootloader = parseNibbles data[5]
      versions.basic = parseNibbles data[6]
      versions.macros = parseNibbles data[7]
    if responseVersion >= 2
      versions.api =
        major: data[8]
        minor: data[9]
    versions

  # Obtains the robot's hackability.
  #
  # @return {Promise<String>} resolved with a string describing the device's
  #   mode; the string will either be 'normal' or 'hack'
  getDeviceMode: ->
    command = new Command 0x02, 0x44, 0
    @_session.sendCommand(command).then (response) ->
      Robot._deviceModeFromCode response.data[0]

  # Sets the robot's hackability.
  #
  # @param {String} mode either 'normal' or 'hack'
  # @return {Promise<Boolean>} resolved with true when the command completes
  setDeviceMode: (mode) ->
    command = new Command 0x02, 0x42, 1
    command.setDataUint8 0, Robot._deviceModeCode(mode)
    @_session.sendCommand(command).then (response) ->
      true

  # Converts a user-friendly device mode string into a code for the Sphero API.
  #
  # @param {String} mode either 'normal' or 'hack'
  # @return {Integer} the Sphero API code for the given device mode
  @_deviceModeCode: (mode) ->
    switch mode
      when 'normal'
        0
      when 'hack'
        1
      else
        mode

  # Coverts a Sphero API device mode code into a user-friendly string.
  #
  # @param {Integer} modeCode the Sphero API code for the given device mode
  # @return {String} either 'normal' or 'hack'
  @_deviceModeFromCode: (modeCode) ->
    switch modeCode
      when 0
        'normal'
      when 1
        'hack'
      else
        modeCode

  # Obtains the robot's configuration flags that persist across power cycles.
  #
  # @return {Promise<Object>} resolved with a JSON-serializable object with one
  #   boolean value per flag
  getPermanentFlags: ->
    command = new Command 0x02, 0x36, 0
    @_session.sendCommand(command).then (response) ->
      Robot._permanentFlagsFromCode response.data.readUInt32BE(0)

  # Sets the robot's flags that persist across power cycles.
  #
  # @param {Object<String, Boolean>} flags a JSON-serializable object with one
  #   boolean value per flag
  # @option flags {Boolean} noSleepWhileCharging
  # @option flags {Boolean} vectorDrive
  # @option flags {Boolean} noLevelingWhileCharging
  # @option flags {Boolean} tailLedAlwaysOn
  # @option flags {Boolean} motionTimeouts
  # @option flags {Boolean} demoMode
  # @option flags {Boolean} lightDoubleTap
  # @option flags {Boolean} heavyDoubleTap
  # @option flags {Boolean} gyroMaxAsync
  # @return {Promise<Boolean>} resolved with true when the command completes
  setPermanentFlags: (flags) ->
    command = new Command 0x02, 0x35, 4
    command.setDataUint32 0, Robot._permanentFlagsCode(flags)
    @_session.sendCommand(command).then (response) ->
      true

  # Converts a developer-friendly map of permanent flags to a Sphero API code.
  #
  # @param {Object<String, Boolean>} flags a JSON-serializable object with one
  #   boolean value per flag
  # @return {Number} a 32-bit integer containing the permanent flags
  @_permanentFlagsCode: (flags) ->
    code = 0
    for own name, value of flags
      unless mask = @_permanentFlagMasks[name]
        throw new Error("Unknown flag #{name}")
      code |= mask if value
    code

  # Converts a Sphero API permanent flags value into a developer-friendly map.
  #
  # @param {Number} flagsCode a 32-bit integer containing the permanent flags
  # @return {Object<String, Boolean>} a JSON-serializable object with one
  #   boolean value per flag
  @_permanentFlagsFromCode: (flagsCode) ->
    flags = {}
    for own name, mask of @_permanentFlagMasks
      if (flagsCode & mask) isnt 0
        flags[name] = true
        flagsCode ^= mask
      else
        flags[name] = false
    unless flagsCode is 0
      throw new Error("Unknown flag bits #{flagsCode}")
    flags

  # @return {Object<String, Number>} maps developer-friendly permanent flag
  #   names to their bit masks
  @_permanentFlagMasks =
    noSleepWhileCharging: 0x01
    vectorDrive: 0x02
    noLevelingWhileCharging: 0x04
    tailLedAlwaysOn: 0x08
    motionTimeouts: 0x10
    demoMode: 0x20
    lightDoubleTap: 0x40
    heavyDoubleTap: 0x80
    gyroMaxAsync: 0x100

  # Sets the power level of the robot's back LED.
  #
  # @param {Number} powerLevel the power level of the robot's back LED; 0 means
  #   that the LED is turned off, and 255 sets the LED at the maximum
  #   brightness
  # @return {Promise<Boolean>} resolved with true when the command completes
  setBackLed: (powerLevel) ->
    command = new Command 0x02, 0x21, 1
    command.setDataUint8 0, powerLevel
    @_session.sendCommand(command).then (response) ->
      true

  # Obtains the color of the robot's RGB LED.
  #
  # @return {Promise<Object>} resolved with a value between 0 and 255
  #   indicating the power level of the robot's back LED
  getUserRgbLed: ->
    command = new Command 0x02, 0x22, 0
    @_session.sendCommand(command).then (response) ->
      {
        red: response.data[0], green: response.data[1],
        blue: response.data[2]
      }

  # Sets the color of the robot's RGB LED.
  #
  # @param {Object} rgb the RGB components that make up the RGB LED color
  # @option rgb {Number} red 0-255
  # @option rgb {Number} green 0-255
  # @option rgb {Number} blue 0-255
  # @return {Promise<Boolean>} resolved with true when the command completes
  setUserRgbLed: (rgb) ->
    command = new Command 0x02, 0x20, 4
    command.setDataUint8 0, rgb.red
    command.setDataUint8 1, rgb.green
    command.setDataUint8 2, rgb.blue
    command.setDataUint8 3, 1
    @_session.sendCommand(command).then (response) ->
      true

  # Reinitializes the macro executive.
  #
  # This aborts the currently running macro and removes all user macros from
  # memory.
  #
  # @return {Promise<Boolean>} resolved with true when the command completes
  resetMacros: ->
    command = new Command 0x02, 0x54, 0
    @_session.sendCommand(command).then (response) ->
      true

  # Obtains information about the currently running macro.
  #
  # @return {Promise<Object?>} resolved with information about the currently
  #   running macro; the object has two keys, 'macroId' and 'commandId'; the
  #   object can be null if no macro is running
  getMacroStatus: ->
    command = new Command 0x02, 0x56, 0
    @_session.sendCommand(command).then (response) ->
      Robot._macroStatusFromData response.data

  # Converts a Sphero API response to developer-friendly macro status data.
  #
  # @param {Buffer} data the Sphero API response
  # @return {Object?<String, Number>} object with two keys, 'macroId' and
  #   'commandId'
  @_macroStatusFromData: (data) ->
    macroId = data[0]
    commandId = data.readUInt16BE 1
    if macroId is 0
      null
    else
      if macroId < 32
        type = 'system'
      else if macroId is 0xFE
        type = 'streaming'
      else if macroId is 0xFF
        type = 'temporary'
      else
        type = 'user'
      { macroId: macroId, commandId: commandId, type: type  }

  # Stops the currently running macro.
  #
  # @return {Promise<Object?>} resolves to information about the aborted macro;
  #   the object has two keys, 'macroId' and 'commandId'
  abortMacro: ->
    command = new Command 0x02, 0x55, 0
    @_session.sendCommand(command).then (response) ->
      status = Robot._macroStatusFromData response.data
      return status if status is null

      if status.commandId is 0xFFFF
        # TODO(pwnall): come up with a better way to point out system macros
        status.aborted = false
      else
        status.aborted = true
      status

  # Stores a macro in the robot's memory.
  #
  # @param {Number} macroId the macro's ID number; 255 is the temporary macro,
  #   254 is the streaming macro, and 0-31 are system macros
  # @param {Buffer} macroBytes the compiled macro's contents
  # @return {Promise<Boolean>} resolves to true when the command completes
  setMacro: (macroId, macroBytes) ->
    if macroId is 0xFF
      commandId = 0x51  # Save temporary macro.
      macroId = 0
    else
      commandId = 0x52  # Save macro.
    command = new Command 0x02, commandId, 1 + macroBytes.length
    command.setDataUint8 0, macroId
    command.setDataBytes 1, macroBytes
    @_session.sendCommand(command).then (response) ->
      true

  # Runs a macro.
  #
  # @param {Number} macroId the macro's ID number; 0-31 are system macros,
  #   32-253 are user-persistent macros, 254 is the streaming macro, and 255
  #   is the temporary macro
  # @return {Promise<Boolean>} resolves to true when the macro has been queued
  #   for execution
  runMacro: (macroId) ->
    command = new Command 0x02, 0x50, 1
    command.setDataUint8 0, macroId
    @_session.sendCommand(command).then (response) ->
      true

  # Aborts the currently running orBasic program.
  #
  # @return {Promise<Boolean>} resolved with true when the command completes
  abortBasic: ->
    command = new Command 0x02, 0x63, 0
    @_session.sendCommand(command).then (response) ->
      true

  # Executes the orBasic program in a storage area.
  #
  # @param {String} area the area storing the program; 'ram' or 'flash'
  # @param {Number} startLine the line number where the execution should start
  # @return {Promise<Boolean>} resolved with true when the command completes
  executeBasic: (area, startLine) ->
    command = new Command 0x02, 0x62, 3
    command.setDataUint8 0, Robot._basicAreaToCode(area)
    command.setDataUint16 1, startLine
    @_session.sendCommand(command).then (response) ->
      true

  # Loads an orBasic program into a storage area.
  #
  # This is a convenience wrapper around the {Robot#eraseBasicArea} and
  # {Robot#appendBasicToArea} primitives.
  #
  # @param {String} area the area storing the program; 'ram' or 'flash'
  # @param {String} fragment the orBasic program fragment to be appended
  # @return {Promise<Boolean>} resolved with true when the command completes
  loadBasic: (area, program) ->
    program += "\0" unless program.endsWith("\0")

    offset = 0
    loadNextFragment = =>
      length = program.length - offset
      length = 253 if length > 253
      if length is 0
        return Promise.resolve true
      @appendBasicToArea(area, program.substring(offset, offset + length))
        .then ->
          offset += length
          loadNextFragment()
    @eraseBasicArea(area).then loadNextFragment

  # Erases an orBasic program.
  #
  # This is a primitive operation used by {Robot#loadBasic}.
  #
  # @param {String} area the area storing the program; 'ram' or 'flash'
  # @return {Promise<Boolean>} resolved with true when the command completes
  eraseBasicArea: (area) ->
    command = new Command 0x02, 0x60, 1
    command.setDataUint8 0, Robot._basicAreaToCode(area)
    @_session.sendCommand(command).then (response) ->
      true

  # Appends an orBasic program fragment to a storage area.
  #
  # This is a primitive operation used by {Robot#loadBasic}.
  #
  # @param {String} area the area storing the program; 'ram' or 'flash'
  # @param {String} fragment the orBasic program fragment to be appended
  # @return {Promise<Boolean>} resolved with true when the command completes
  appendBasicToArea: (area, fragment) ->
    command = new Command 0x02, 0x61, 1 + fragment.length
    command.setDataUint8 0, Robot._basicAreaToCode(area)
    command.setDataString 1, fragment
    @_session.sendCommand(command).then (response) ->
      true

  # Converts a developer-friendly orBasic storage area to a Sphero API code.
  #
  # @param {String} area an orBasic area; 'ram' or 'flash'
  # @return {Number} the Sphero API code for the area
  @_basicAreaToCode: (area) ->
    switch area
      when 'ram'
        0
      when 'flash'
        1
      else
        area

  # Called when an asynchronous message is received from the robot.
  #
  # @param {Object} async the asynchronous message
  _onAsync: (async) ->
    switch async.idCode
      when 0x06
        event =
          markerId: async.data[0], macroId: async.data[1],
          commandId: async.data.readUInt16BE(2)
        @emit 'macro', event
      when 0x08
        event = { message: async.data.toString('ascii') }
        @emit 'basicPrint', event
      when 0x09
        event = { message: async.data.toString('ascii') }
        @emit 'basicError', event
      else
        @emit 'async', async


module.exports = Robot
