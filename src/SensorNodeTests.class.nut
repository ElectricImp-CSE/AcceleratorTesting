// Sensor Node Tests
SensorNodeTests = class {

    static LED_ON = 0;
    static LED_OFF = 1;

    _enableAccelInt = null;
    _enablePressInt = null;
    _enableTempHumidInt = null;

    _intHandler = null;

    _wake = null;

    tempHumid = null;
    press = null;
    accel = null;

    ow = null;

    SensorNode_003 = null;

    led_blue = null;
    led_green = null;

    testDone = false;

    constructor(enableAccelInt, enablePressInt, enableTempHumidInt, intHandler) {
        // Sensor Node HAL
        SensorNode_003 = {
            "LED_BLUE" : hardware.pinP,
            "LED_GREEN" : hardware.pinU,
            "SENSOR_I2C" : hardware.i2cAB,
            "TEMP_HUMID_I2C_ADDR" : 0xBE,
            "ACCEL_I2C_ADDR" : 0x32,
            "PRESSURE_I2C_ADDR" : 0xB8,
            "RJ12_ENABLE_PIN" : hardware.pinS,
            "ONEWIRE_BUS_UART" : hardware.uartDM,
            "RJ12_I2C" : hardware.i2cFG,
            "RJ12_UART" : hardware.uartFG,
            "WAKE_PIN" : hardware.pinW,
            "ACCEL_INT_PIN" : hardware.pinT,
            "PRESSURE_INT_PIN" : hardware.pinX,
            "TEMP_HUMID_INT_PIN" : hardware.pinE,
            "NTC_ENABLE_PIN" : hardware.pinK,
            "THERMISTER_PIN" : hardware.pinJ,
            "FTDI_UART" : hardware.uartQRPW,
            "PWR_3v3_EN" : hardware.pinY
        }

        imp.enableblinkup(true);
        _enableAccelInt = enableAccelInt;
        _enablePressInt = enablePressInt;
        _enableTempHumidInt = enableTempHumidInt;

        _intHandler = intHandler;

        _wake = SensorNode_003.WAKE_PIN;

        SensorNode_003.SENSOR_I2C.configure(CLOCK_SPEED_400_KHZ);
        SensorNode_003.RJ12_I2C.configure(CLOCK_SPEED_400_KHZ);

        // initialize sensors
        tempHumid = HTS221(SensorNode_003.SENSOR_I2C, SensorNode_003.TEMP_HUMID_I2C_ADDR);
        press = LPS22HB(SensorNode_003.SENSOR_I2C, SensorNode_003.PRESSURE_I2C_ADDR);
        accel = LIS3DH(SensorNode_003.SENSOR_I2C, SensorNode_003.ACCEL_I2C_ADDR);
        ow = Onewire(SensorNode_003.ONEWIRE_BUS_UART, true);

        // configure leds
        led_blue = SensorNode_003.LED_BLUE;
        led_green = SensorNode_003.LED_GREEN;
        led_blue.configure(DIGITAL_OUT, LED_OFF);
        led_green.configure(DIGITAL_OUT, LED_OFF);

        _checkWakeReason();
    }

    function scanSensorI2C() {
        local addrs = [];
        for (local i = 2 ; i < 256 ; i+=2) {
            if (SensorNode_003.SENSOR_I2C.read(i, "", 1) != null) {
                server.log(format("Device at address: 0x%02X", i));
                addrs.push(i);
            }
        }
        return addrs;
    }

    function scanRJ12I2C() {
        SensorNode_003.PWR_3v3_EN.configure(DIGITAL_OUT, 1);
        local addrs = [];
        SensorNode_003.RJ12_ENABLE_PIN.configure(DIGITAL_OUT, 1);
        for (local i = 2 ; i < 256 ; i+=2) {
            if (SensorNode_003.RJ12_I2C.read(i, "", 1) != null) {
                server.log(format("Device at address: 0x%02X", i));
                addrs.push(i);
            }
        }
        SensorNode_003.PWR_3v3_EN.write(0);
        return addrs;
    }

    function testSleep() {
        server.log("At full power...");
        imp.wakeup(10, function() {
            server.log("Going to deep sleep for 20s...");
            accel.enable(false);
            imp.onidle(function() { imp.deepsleepfor(20); })
        }.bindenv(this))
    }

    function testTempHumid() {
        // Take a sync reading and log it
        tempHumid.setMode(HTS221_MODE.ONE_SHOT);
        local thReading = tempHumid.read();
        if ("error" in thReading) {
            server.error(thReading.error);
            return false;
        } else {
            server.log(format("Current Humidity: %0.2f %s, Current Temperature: %0.2f °C", thReading.humidity, "%", thReading.temperature));
            return ((thReading.humidity > 0 && thReading.humidity < 100) && (thReading.temperature > 10 && thReading.temperature < 50));
        }
    }

    function testAccel() {
        // Take a sync reading and log it
        accel.init();
        accel.setDataRate(10);
        accel.enable();
        local accelReading = accel.getAccel();
        server.log(format("Acceleration (G): (%0.2f, %0.2f, %0.2f)", accelReading.x, accelReading.y, accelReading.z));
        return (accelReading.x > -1.5 && accelReading.x < 1.5) && (accelReading.y > -1.5 && accelReading.y < 1.5) && (accelReading.z > -1.5 && accelReading.z < 1.5)
    }

    function testPressure() {
        // Take a sync reading and log it
        press.softReset();
        local pressReading = press.read();
        if ("error" in pressReading) {
            server.error(pressReading.error);
            return false;
        } else {
            server.log("Current Pressure: " + pressReading.pressure);
            return (pressReading.pressure > 800 && pressReading.pressure < 1200);
        }
    }

    function testOnewire() {
        SensorNode_003.PWR_3v3_EN.configure(DIGITAL_OUT, 1);
        SensorNode_003.RJ12_ENABLE_PIN.configure(DIGITAL_OUT, 1);
        if (ow.reset()) {
            local devices = ow.discoverDevices();
            foreach (id in devices) {
                local str = ""
                foreach(idx, val in id) {
                    str += val
                    if (idx < id.len() - 1) str += ".";
                }
                server.log("Found device with id: " + str);
            }
            return (devices.len() > 0);
        }
        SensorNode_003.PWR_3v3_EN.write(0);
        return false;
    }

    function testLEDOn(led) {
        led.configure(DIGITAL_OUT, LED_ON);
        // server.log("Turning LED ON")
    }

    function testLEDOff(led) {
        led.write(LED_OFF);
        // server.log("Turning LED OFF")
    }

    function testInterrupts(testWake = false) {
        clearInterrupts();

        // Configure interrupt pins
        _wake.configure(DIGITAL_IN_WAKEUP, function() {
            // When awake only trigger on pin high
            if (!testWake && _wake.read() == 0) return;

            local accelReading = accel.getAccel();
            server.log(format("Acceleration (G): (%0.2f, %0.2f, %0.2f)", accelReading.x, accelReading.y, accelReading.z));

            // Determine interrupt
            if (_enableAccelInt) _accelIntHandler();
            if (_enablePressInt) _pressIntHandler();

        }.bindenv(this));

        if (_enableAccelInt) _enableAccelInterrupt();
        if (_enablePressInt) _enablePressInterrupt();

        if (testWake) {
            _sleep();
        }
    }

    function logIntPinState() {
        server.log("Wake pin: " + _wake.read());
        server.log("Accel int pin: " + SensorNode_003.ACCEL_INT_PIN.read());
        server.log("Press int pin: " + SensorNode_003.PRESSURE_INT_PIN.read());
    }

    // Private functions/Interrupt helpers
    // -------------------------------------------------------

    function _checkWakeReason() {
        local wakeReason = hardware.wakereason();
        switch (wakeReason) {
            case WAKEREASON_PIN:
                // Woke on interrupt pin
                server.log("Woke b/c int pin triggered");
                testDone = true;
                server.log("nv" in getroottable())
                if (_enableAccelInt) _accelIntHandler();
                if (_enablePressInt) _pressIntHandler();
                break;
            case WAKEREASON_TIMER:
                // Woke on timer
                server.log("Woke b/c timer expired");
                break;
            default :
                // Everything else
                server.log("Rebooting...");
        }
    }

    function _sleep() {
        if (_wake.read() == 1) {
            // logIntPinState();
            imp.wakeup(1, _sleep.bindenv(this));
        } else {
            // sleep for 24h
            imp.onidle(function() { server.sleepfor(86400); });
        }
    }

    function clearInterrupts() {
        accel.configureFreeFallInterrupt(false);
        press.configureThresholdInterrupt(false);
        accel.getInterruptTable();
        press.getInterruptSrc();
        // logIntPinState();
    }

    function _enableAccelInterrupt() {
        accel.setDataRate(100);
        accel.enable();
        accel.configureInterruptLatching(true);
        accel.getInterruptTable();
        accel.configureFreeFallInterrupt(true);
        server.log("Free fall interrupt configured...");
        // accel.configureClickInterrupt(true, LIS3DH.DOUBLE_CLICK, 1.5, 5, 10, 50);
        // server.log("Double Click interrupt configured...");
    }

    function _accelIntHandler() {
        local intTable = accel.getInterruptTable();
        if (intTable.int1) server.log("Free fall detected: " + intTable.int1);
        // if (intTable.click) server.log("Click detected: " + intTable.click);
        // if (intTable.singleClick) server.log("Single click detected: " + intTable.singleClick);
        // if (intTable.doubleClick) server.log("Double click detected: " + intTable.doubleClick);
        _intHandler(intTable);
    }

    function _enablePressInterrupt() {
        press.setMode(LPS22HB_MODE.CONTINUOUS, 25);
        local intTable = press.getInterruptSrc();
        // this should always fire...
        press.configureThresholdInterrupt(true, 1000, LPS22HB.INT_LATCH | LPS22HB.INT_HIGH_PRESSURE);
        server.log("Pressure interrupt configured...");
    }

    function _pressIntHandler() {
        local intTable = press.getInterruptSrc();
        if (intTable.int_active) {
            server.log("Pressure int triggered: " + intTable.int_active);
            if (intTable.high_pressure) server.log("High pressure int: " + intTable.high_pressure);
            if (intTable.low_pressure) server.log("Low pressure int: " + intTable.low_pressure);
        }
        _intHandler(intTable);
    }

}