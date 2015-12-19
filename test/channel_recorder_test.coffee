Recorder = SpheroPwn.ChannelRecorder

fs = require 'fs'
temp = require('temp').track()

describe 'ChannelRecoder', ->
  beforeEach (done) ->
    temp.open 'recorder-', (error, info) =>
      throw error if error
      @path = info.path
      fs.close info.fd, (error) =>
        throw error if error
        done()

  afterEach (done) ->
    temp.cleanup (error, stats) ->
      throw error if error
      done()

