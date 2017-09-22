#require "FactoryTools.class.nut:2.1.0"

class AcceleratorTestingFactoryAgent {

    constructor(debug = false) {
        FactoryTools.isFactoryFirmware(function(isFactoryEnv) {
            if (isFactoryEnv) {
                FactoryTools.isDeviceUnderTest() ? RunDeviceUnderTest(debug) : RunFactoryFixture(debug);
            } else {
              server.log("This firmware is not running in the Factory Environment");
            }
        }.bindenv(this));
    }

    @include "RunFactoryFixture.agent.nut";
    @include "RunDeviceUnderTest.agent.nut";
}

// Runtime
// --------------------------------------
server.log("Agent Running...");

local ENABLE_DEBUG_LOGS = true;

AcceleratorTestingFactoryAgent(ENABLE_DEBUG_LOGS);
