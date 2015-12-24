Discovery = require './discovery.coffee'

# Called when "npm start" is called.
module.exports = ->
  Discovery.on 'channel', (channel) ->
    console.log "Discovered Sphero: #{channel.sourceId}"
  Discovery.on 'error', (error) ->
    console.error error
  Discovery.start()
