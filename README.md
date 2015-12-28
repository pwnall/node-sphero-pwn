# Node.js Sphero Driver

[![Build Status](https://travis-ci.org/pwnall/node-sphero-pwn.svg)](https://travis-ci.org/pwnall/node-sphero-pwn)
[![API Documentation](http://img.shields.io/badge/API-Documentation-ff69b4.svg)](http://coffeedoc.info/github/pwnall/node-sphero-pwn)
[![NPM Version](http://img.shields.io/npm/v/sphero-pwn.svg)](https://www.npmjs.org/package/sphero-pwn)

This is a [node.js](http://nodejs.org/) driver for the
[communication protocol used by Sphero's robots](http://sdk.sphero.com/api-reference/api-packet-format/).

This project is an independent effort from the official
[sphero.js](https://github.com/orbotix/sphero.js) project, and is less
supported. At the same time, we are free to develop functionality that is
unlikely to be added to the official project, such as driving a
[BB-8](http://www.sphero.com/starwars).

This project is written in [CoffeeScript](http://coffeescript.org/) and tested
using [mocha](http://visionmedia.github.io/mocha/).


## Usage

This package's API relies heavily on
[ES6 Promises](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise).

Each robot that your computer can connect to receives an identifier. The
following command looks for reachable robots and shows their identifiers.

```bash
npm start
```

Once you have an identifier, you can use the discovery service to connect to
the robot, as shown below. The discovery service has
[other useful methods](src/discovery.coffee) as well.

```javascript
var sphero = require('sphero-pwn');
var robot = null;
sphero.Discovery.findChannel('serial:///dev/cu.Sphero-YRG-AMP-SPP').
    then(foundChannel);  // foundChannel is defined below.
```

The discovery service produces a communication channel, which can be used to
create a `Robot`. [Robot's methods](src/robot.coffee) are convenient wrappers
for the
[Sphero API commands](http://sdk.sphero.com/api-reference/api-quick-reference/).

```javascript
function foundChannel(channel) {
  console.log("Found robot");
  robot = new sphero.Robot(channel);

  play();  // play is defined below.
}
```

For example, the following snippet sets the Sphero's permanent RGB LED color.

```javascript
function play() {
  robot.setUserRgbLed({red: 255, green: 128, blue: 0}).
    then(function() {
      console.log("Set LED color");
      robot.close();
    }).
    then(function() {
      console.log("Done");
    });
}
```

The following example uses
[orbBasic](http://sdk.sphero.com/robot-languages/orbbasic/) to flash the
robot's RGB LED.

```javascript
function play() {
  robot.on('basic', function(event) {
    console.log("basic print: " + event.message);
  });
  robot.on('basicError', function(event) {
    console.log("basic error: " + event.message);
  });
  var script = "10 RGB 0, 255, 0\n" +
               "20 delay 2000\n" +
               "30 RGB 0, 0, 255\n" +
               "40 delay 2000\n";
  robot.loadBasic("ram", script).
    then(function() {
      console.log("Loaded script");
      robot.runBasic("ram", 10);
    }).
    then(function() {
      console.log("Started script");
      robot.close();
    }).
    then(function() {
      console.log("Done");
    }).
    catch(function() {
      console.error(error)
    });
}
```

Last, the following example uses our
[macro compiler](https://github.com/pwnall/node-sphero-pwn-macros) to compile
and execute a [macro](http://sdk.sphero.com/robot-languages/macros/) that
flashes the robot's RGB LED.

```javascript
var macros = require('sphero-pwn-macros');

function play() {
  var macroSource = "rgb 0 255 0\n" +
                    "delay 2000\n" +
                    "rgb 0 0 255\n" +
                    "delay 2000\n";
  var macro = macros.compile(macroSource);

  robot.on('macro', function(event) {
    console.log("macro marker: " + event.markerId);
  });
  robot.setMacro(0xFF, new Buffer(macro.bytes)).
    then(function() {
      console.log("Loaded macro in RAM");
      robot.runMacro(0xFF);
    }).
    then(function() {
      console.log("Started macro");
      robot.close();
    }).
    then(function() {
      console.log("Done");
    }).
    catch(function() {
      console.error(error)
    });
}
```


## Development Setup

Install all the dependencies.

```bash
npm install
```

List the Bluetooth devices connected to your computer.

```bash
npm start
```

Set the `SPHERO_DEV` environment variable to point to your Sphero.

```bash
export SPHERO_DEV=serial:///dev/cu.Sphero-XXX-AMP-SPP
export SPHERO_DEV=ble://ef:80:a8:4a:12:34
```

Run the tests.

```bash
npm test
```


## License

This project is Copyright (c) 2015 Victor Costan, and distributed under the MIT
License.
