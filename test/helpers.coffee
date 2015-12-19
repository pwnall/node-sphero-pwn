global.chai = require 'chai'
global.sinon = require 'sinon'

sinonChai = require 'sinon-chai'
global.chai.use sinonChai

global.SpheroPwn = require '../lib/index.js'

global.spheroTestConfig =
  rfconnPath: process.env['SPHERO_DEV']

path = require 'path'

# The path to a recording file in the test recordings directory.
#
# @param {String} name the recording name; each test case should use its own
#   recordings
# @return {String} a full path to the file holding the desired recording
global.testRecordingPath = (name) ->
  path.join __dirname, 'data', "#{name}.txt"


global.assert = global.chai.assert
global.expect = global.chai.expect
