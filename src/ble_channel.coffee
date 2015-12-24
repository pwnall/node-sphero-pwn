# Bluetooth LE communication channel with a robot.
class BleChannel
  # Creates a channel over a set of discovered Bluetooth LE characteristics.
  #
  # @param {Peripheral} peripheral
  # @param {Object<String, Object<String, Characteristic>>} characteristics
  #   the Bluetooth LE characteristics that make up a communication channel
  constructor: (peripheral, characteristics) ->
    @sourceId = "ble://#{peripheral.address}"
    @_peripheral = peripheral
    @_characteristics = characteristics
    @_characteristics.robot.responses.addListener 'data', (data) =>
      @onData data
    @_openPromise = null
    @_closePromise = null

  # @see {SerialChannel#open}
  open: ->
    @_openPromise ||= @_activate()

  # @see {SerialChannel#write}
  write: (data) =>
    @open()
      .then =>
        new Promise (resolve, reject) =>
          @_characteristics.robot.commands.write data, false, (error) =>
            if error
              reject error
            else
              resolve true

  # @see {SerialChannel#close}
  close: ->
    @open()
      .then =>
        @_closePromise ||= new Promise (resolve, reject) =>
          @_peripheral.disconnect()
          resolve true

  # @see {SerialChannel#onData}
  onData: (data) ->
    return

  # @see {SerialChannel#onError}
  onError: (error) ->
    return

  # @see {SerialChannel#sourceId}
  sourceId: null

  # Performs the serial channel activation sequence.
  #
  # @return {Promise<Boolean>} resolved with true when the robot received the
  #   commands needed to activate the serial channel
  _activate: ->
    chain = Promise.resolve true
    for write in BleChannel._activationSequence
      do (write) =>
        name = write[0]
        buffer = write[1]
        chain = chain.then =>
          BleChannel._bleWrite @_characteristics.radio[write[0]], write[1]
    chain.then =>
      BleChannel._bleNotify @_characteristics.robot.responses

  # Connects to a robot over Bluetooth LE.
  #
  # @param {Peripheral} peripheral a Bluetooth LE peripheral that might be a
  #   Sphero robot
  # @return {Promise<BleChannel?>} resolved with a {BleChannel} instance
  #   connecting to the robot represented by the given peripheral; the instance
  #   may be null if the peripheral is not a Sphero robot
  @fromPeripheral: (peripheral) ->
    @_bleConnect(peripheral)
      .then =>
        @_bleGetServices(peripheral)
      .then (services) =>
        if services is null
          peripheral.disconnect()
          return null
        @_bleGetCharacteristics peripheral, services
      .then (characteristics) =>
        if characteristics is null
          peripheral.disconnect()
          return null
        new BleChannel peripheral, characteristics

  # Enables notifications coming in from a Bluetooth LE characteristic.
  #
  # @param {Characteristic} characteristic the Bluetooth LE characteristic
  #   whose change notifications will be received
  # @return {Promise<Boolean>} resolved with true when the characteristic's
  #   notifications are enabled
  @_bleNotify: (characteristic) ->
    new Promise (resolve, reject) ->
      characteristic.notify true, (error) ->
        if error
          reject error
          return
        resolve true

  # Writes to a Bluetooth LE characteristic.
  #
  # @param {Characteristic} characteristic the Bluetooth LE characteristic
  # @param {Buffer} data the data that will be written to the characteristic
  # @return {Promise<Boolean>} resolved with true when the characteristic is
  #   written
  @_bleWrite: (characteristic, data) ->
    new Promise (resolve, reject) =>
      characteristic.write data, true, (error) =>
        if error
          reject error
          return
        resolve true

  # Connects to a Bluetooth LE peripheral.
  #
  # @param {Peripheral} peripheral a Bluetooth LE peripheral that might be a
  #   Sphero robot
  # @return {Promise<Boolean>} resolved with true when the peripheral is
  #   connected
  @_bleConnect: (peripheral) ->
    new Promise (resolve, reject) ->
      onBleConnect = ->
        peripheral.removeListener 'connect', onBleConnect
        resolve true
      peripheral.addListener 'connect', onBleConnect
      peripheral.connect()

  # Discovers the robot's Bluetooth LE services.
  #
  # @param {Peripheral} peripheral a Bluetooth LE peripheral that might be a
  #   Sphero robot
  # @return {Promise<Boolean>} resolved with an object containing the robot's
  #   services, indexed by type; null if the peripheral does not have all the
  #   services of a Sphero robot
  @_bleGetServices: (peripheral) ->
    new Promise (resolve, reject) =>
      uuidList = Object.getOwnPropertyNames @_serviceUuids
      peripheral.discoverServices uuidList, (error, list) =>
        if error
          reject error
          peripheral.disconnect()
          return
        resolve @_extractBleObjects(@_serviceUuids, list)

  # Extracts Bluetooth LE objects by their UUIDs from a list of objects.
  #
  # @param {Object<String, String>} uuids maps the desired UUIDs to
  #   developer-friendly object names
  # @param {Array<Object>} list the list that contains the desired Bluetooth
  #   objects
  # @return {Object?} the desired Bluetooth LE objects, indexed by name; null
  #   if the
  #   list of services does not include all the robot's services
  @_extractBleObjects: (uuids, list) ->
    objects = {}
    for object in list
      if name = uuids[object.uuid]
        objects[name] = object
    for own uuid, name of uuids
      return null unless objects[name]
    objects

  # Discovers the characteristics of a robot's Bluetooth LE services.
  #
  # @param {Peripheral} periperheral the Bluetooth LE peripheral whose
  #   characteristics are getting discovered
  # @param {Object<String, Service>} services maps developer-friendly service
  #   names to the Bluetooth LE services whose characteristics shall be
  #   discovered
  # @return {Promise<Object?<String, Object<String, Characteristic>>>} resolves
  #   with a mapping from developer-friendly service and characteristic names
  #   to Bluetooth LE characteristics; the mapping may be null if any of the
  #   services is missing a characteristic
  @_bleGetCharacteristics: (peripheral, services) ->
    promiseList = for name, service of services
      @_bleGetServiceCharacteristics peripheral, name, service
    Promise.all(promiseList).then (resolutions) ->
      result = {}
      for resolution in resolutions
        name = resolution[0]
        characteristics = resolution[1]
        if characteristics is null
          return null
        result[name] = characteristics
      result

  # Discovers the characteristics of a Bluetooth LE service.
  #
  # @param {Peripheral} periperheral the Bluetooth LE peripheral whose
  #   characteristics are getting discovered
  # @param {Service} service the service whose characteristics are getting
  #   discovered
  # @param {String} developer-friendly name for the service whose
  #   characteristics are getting discovered
  # @return {Promise<Array<String, Object<String, Characteristic>>} resolves
  #   with a 2-element array; the first element is the service's
  #   developer-friendly name, and the second element maps developer-friendly
  #   characteristic names to Bluetooth LE characteristics; the second element
  #   may be null if any of the desired characteristics is missing
  @_bleGetServiceCharacteristics: (peripheral, name, service) ->
    new Promise (resolve, reject) =>
      uuids = @_characteristicUuids[name]
      uuidList = Object.getOwnPropertyNames uuids
      service.discoverCharacteristics uuidList, (error, list) =>
        if error
          peripheral.disconnect()
          reject error
          return
        resolve [name, @_extractBleObjects(uuids, list)]

  # @return  {Object<String, String>} UUIDs for Sphero BLE services
  @_serviceUuids:
    '22bb746f2ba075542d6f726568705327': 'robot'
    '22bb746f2bb075542d6f726568705327': 'radio'

  # @return {Object<String, String>} UUIDs for the interesting characteristics
  #   of the radio service
  @_characteristicUuids:
    radio:
      '22bb746f2bbd75542d6f726568705327': 'antiDos'
      '22bb746f2bb275542d6f726568705327': 'txPower'
      '22bb746f2bbf75542d6f726568705327': 'wakeCpu'
    robot:
      '22bb746f2ba175542d6f726568705327': 'commands'
      '22bb746f2ba675542d6f726568705327': 'responses'

  # @return {Array<String, Buffer>} the sequence of data that must be written
  #   to the robot's radio characteristics to activate its serial connection
  @_activationSequence: [
    ['antiDos', new Buffer("011i3")],
    ['txPower', new Buffer("\x0007")],
    ['wakeCpu', new Buffer("\x01")],
  ]


module.exports = BleChannel
