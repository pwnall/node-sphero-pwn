global.chai = require 'chai'
global.sinon = require 'sinon'

sinonChai = require 'sinon-chai'
global.chai.use sinonChai

global.SpheroPwn = require '../lib/index.js'

global.sphero_test_config =
  rfconnPath: process.env['SPHERO_DEV']

global.assert = global.chai.assert
global.expect = global.chai.expect
