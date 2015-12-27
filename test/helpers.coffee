global.chai = require 'chai'
global.sinon = require 'sinon'

sinonChai = require 'sinon-chai'
global.chai.use sinonChai

global.assert = global.chai.assert
global.expect = global.chai.expect

global.SpheroPwn = require '../lib/index.js'

global.spheroTestConfig =
  rfconnPath: process.env['SPHERO_DEV']

fs = require 'fs-promise'
path = require 'path'


# The path to a recording file in the test recordings directory.
#
# @param {String} recordingName used to name the recording file; each test case
#   should use its own recordings
# @return {String} a full path to the file holding the desired recording
global.testRecordingPath = (recordingName) ->
  path.join __dirname, 'data', "#{recordingName}.txt"

# Creates a channel recording to a file.
#
# @param {String} recordingName used to name the recording file; each test case
#   should use its own recordings
# @return {Channel} a {ReplayChannel} if the recording exists, otherwise a
#   {ChannelRecorder} wrapping a {Channel} to the live device pointed to by the
#   SPHERO_DEV environment variable
global.testRecordingChannel = (recordingName) ->
  recordingPath = testRecordingPath recordingName
  fs.stat(recordingPath)
    .then ->
      channel = new SpheroPwn.ReplayChannel(recordingPath)
      channel.open().then -> channel
    .catch (error) ->
      SpheroPwn.Discovery.findChannel(process.env['SPHERO_DEV'])
        .then (channel) ->
          recorder = new SpheroPwn.ChannelRecorder channel, recordingPath
          recorder.open().then -> recorder
