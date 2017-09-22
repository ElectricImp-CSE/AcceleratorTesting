#require "W5500.device.nut:1.0.0"
#require "CRC16.class.nut:1.0.0"
#require "ModbusRTU.class.nut:1.0.0"
#require "ModbusMaster.class.nut:1.0.0"
#require "Modbus485Master.class.nut:1.0.0"
#require "promise.class.nut:3.0.1"

// Factory Tools Lib
#require "FactoryTools.class.nut:2.1.0"
// Factory Fixture Keyboard/Display Lib
#require "CFAx33KL.class.nut:1.1.0"
// Printer Driver
@include "QL720NW.device.nut";

// USB Driver Library
@include "USB.device.lib.nut";
@include "FtdiUsbDriver.device.lib.nut";
// ADC Library
@include "MCP3208.device.lib.nut";

class AcceleratorTestingFactory {

    constructor(ssid, password) {
        FactoryTools.isFactoryFirmware(function(isFactoryEnv) {
            if (isFactoryEnv) {
                FactoryTools.isFactoryImp() ? RunFactoryFixture(ssid, password) : RunDeviceUnderTest();
            } else {
              server.log("This firmware is not running in the Factory Environment");
            }
        }.bindenv(this))
    }

    @include "RunFactoryFixture.device.nut";
    @include "RunDeviceUnderTest.device.nut";
}

// // Factory Code
// // ------------------------------------------
server.log("Device Running...");

const SSID = "";
const PASSWORD = "";

AcceleratorTestingFactory(SSID, PASSWORD);