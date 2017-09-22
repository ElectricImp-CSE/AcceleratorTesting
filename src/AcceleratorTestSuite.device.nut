AcceleratorTestSuite = class {

	// NOTE: LED test are not included in this class
	
	// Requires an echo server (RasPi)
	// Test opens a connection and receiver
	// Sends the test string
	// Checks resp for test string
	// Closes the connection
	function wiznetEchoTest(wiz) {
		server.log("Wiznet test.");
		local wiznetTestStr = "SOMETHING";

		return Promise(function(resolve, reject) {
			wiz.onReady(function() {
				// Connection settings
			    local destIP   = "192.168.201.3";
			    local destPort = 4242;
			    local sourceIP = "192.168.201.2";
			    local subnet_mask = "255.255.255.0";
			    local gatewayIP = "192.168.201.1";
			    wiz.configureNetworkSettings(sourceIP, subnet_mask, gatewayIP);

			    server.log("Attemping to connect via LAN...");
			    // Start Timer
			    local started = hardware.millis();
			    wiz.openConnection(destIP, destPort, function(err, connection) {
			    	// 
			    	local dur = hardware.millis() - started;

			    	if (err) {
			    		local errMsg = format("Connection failed to %s:%d in %d ms: %s", destIP, destPort, dur, err.tostring());
			            if (connection) {
				            connection.close(function() {
				            	return reject(errMsg);
				            });
				        } else {
				        	return reject(errMsg);
				        }
			        } else {
			        	// Create event handlers for this connection
	    		  		connection.onReceive(function(err, resp) {
	    		  			connection.close(function() {
	    		  				server.log("Connection closed. Ok to disconnect cable.")
	    		  			});
	    		  			local respStr = "";
							resp.seek(0, 'b');
							respStr = resp.readstring(9);

							local index = respStr.find(wiznetTestStr); 
							return (index != null) ? resolve("Received expected response") : reject("Expected response not found");
	    		  		}.bindenv(this));
	    		  		connection.transmit(wiznetTestStr, function(err) {
	    		  			if (err) {
	    		  				return reject("Send failed: " + err);
	    		  			} else {
	    		  				server.log("Send successful");
	    		  			}
	    		  		}.bindenv(this))
			        }
			    }.bindenv(this))
			}.bindenv(this));	
		}.bindenv(this))
	}

	// Requires a PLC Click 
	// Reads a register
	// Writes that register with new value
	// Reads that register and checks for new value
	function RS485ModbusTest(modbus, devAddr) {
		server.log("RS485 test.");
		return Promise(function(resolve, reject) {
			local registerAddr = 4;
			local expected = null;
			modbus.read(devAddr, MODBUSRTU_TARGET_TYPE.HOLDING_REGISTER, registerAddr, 1, function(err, res) {
				if (err) return reject("Modbus read error: " + err);
				expected = (typeof res == "array") ? res[0] : res;
				// adjust the value
				(expected > 100) ? expected -- : expected ++;
				modbus.write(devAddr, MODBUSRTU_TARGET_TYPE.HOLDING_REGISTER, registerAddr, 1, expected, function(e, r) {
					if (e) return reject("Modbus write error: " + e);
					modbus.read(devAddr, MODBUSRTU_TARGET_TYPE.HOLDING_REGISTER, registerAddr, 1, function(error, resp) {
						if (error) return reject("Modbus read error: " + error);
						if (typeof resp == "array") resp = resp[0];
						return (resp == expected) ? resolve("RS485 test passed.") : reject("RS485 test failed.");
					}.bindenv(this))
				}.bindenv(this))
			}.bindenv(this))
		}.bindenv(this))
	}

	// Requires special cable to loop pin 1 on both groves together and pin 2 on both groves together
	function analogGroveTest(in1, in2, out1, out2) {
		server.log("Analog Grove Connectors test.");
		return Promise(function(resolve, reject) {
			local ones = 1;
			local twos = 0;
			out1.write(ones);
			out2.write(twos);
			return (in1.read() == ones && in2.read() == twos) ? resolve("Analog grove test passed.") : reject("Analog grove test failed.");
		}.bindenv(this))
	}

	function ADCTest(adc, chan, expected, range) {
		server.log("ADC test.");
		return Promise(function(resolve, reject) {
			local lower = expected - range;
			local upper = expected + range;
			local reading = adc.readADC(chan);
			return (reading > lower && reading < upper) ? resolve("ADC readings on chan " + chan + " in range.") : reject("ADC readings not in range. Chan : " + chan + " Reading: " + reading);
		}.bindenv(this))
	}

	function scanI2CTest(i2c, addr) {
		// note scan doesn't currently work on an imp005
		server.log("i2c bus scan.");
		local count = 0;
		return Promise(function(resolve, reject) {	
        	for (local i = 2 ; i < 256 ; i+=2) {
        		local val = i2c.read(i, "", 1);
            	if (val != null) {
            		count ++;
            		server.log(val);
                	server.log(format("Device at address: 0x%02X", i));
                	if (i == addr) {
                		if (count == 1) {
                			return resolve(format("Found I2C sensor at address: 0x%02X", i));
                		} else {
                			return resolve(format("Found I2C sensor at address: 0x%02X and %i sensors", i, count));
                		}
                	}
            	}
        	}
        	return reject(format("I2C scan did not find sensor at address: 0x%02X", addr));
        }.bindenv(this));
	}

	function ic2test(i2c, addr, reg, expected) {
		server.log("i2c read register test.");
		return Promise(function(resolve, reject) {
			local result = i2c.read(addr, reg.tochar(), 1);
			if (result == null) reject("i2c read error: " + i2c.readerror());
			return (result == expected.tochar()) ? resolve("I2C read returned expected value.") : reject("I2C read returned " + result);
		}.bindenv(this))
	}

	// Requires a USB FTDI device
	// Initializes USB host and FTDI driver
	// Looks for an onConnected FTDI device
	function usbFTDITest() {
		server.log("USB test.");
		return Promise(function(resolve, reject) {
			// Setup usb
			local usbHost = USB.Host(hardware.usb);
			usbHost.registerDriver(FtdiUsbDriver, FtdiUsbDriver.getIdentifiers());
			local timeout = imp.wakeup(5, function() {
				return reject("FTDI USB Driver not found. USB test failed.");
			}.bindenv(this))
			usbHost.on("connected", function(device) {
				imp.cancelwakeup(timeout);
				if (typeof device == "FtdiUsbDriver") {
					return resolve("FTDI USB Driver found. USB test passed.");
				} else {
					return reject("FTDI USB Driver not found. USB test failed.");
				}
			}.bindenv(this));
		}.bindenv(this))
	}

}