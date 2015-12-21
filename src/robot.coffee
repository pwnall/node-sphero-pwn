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

  # Obtains the robot's hackability.
  #
  # @return {Promise<String>} resolved with a string describing the device's
  #   mode; the string will either be 'normal' or 'hack'
  getDeviceMode: ->
    command = new Command 0x02, 0x44, 0
    @_session.sendCommand(command).then (response) ->
      modeCode = response.data[0]
      switch modeCode
        when 0
          'normal'
        when 1
          'hack'
        else
          modeCode

  # Sets the robot's hackability.
  #
  # @param {String} mode either 'normal' or 'hack'
  # @return {Promise<Boolean>} resolved with true when the command completes
  setDeviceMode: (mode) ->
    modeCode = switch mode
      when 'normal'
        0
      when 'hack'
        1
      else
        mode

    command = new Command 0x02, 0x42, 1
    command.setDataUint8 0, modeCode
    @_session.sendCommand(command).then (response) ->
      true


module.exports = Robot
