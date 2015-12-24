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
