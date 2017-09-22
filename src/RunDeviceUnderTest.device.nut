RunDeviceUnderTest = class {
	    static LED_FEEDBACK_AFTER_TEST = 1;
        static PAUSE_BTWN_TESTS = 0.5;

        test = null;

        constructor() {
            test = AcceleratorTestingFactory.RunDeviceUnderTest.AutodeskDiscKitTesting(LED_FEEDBACK_AFTER_TEST, PAUSE_BTWN_TESTS, testsDone.bindenv(this));
            test.run();
        }

        function testsDone(passed) {
            // Only print label for passing hardware
            if (passed) {
                local deviceData = {};
                deviceData.mac <- imp.getmacaddress();
                deviceData.id <- hardware.getdeviceid();
                server.log("Sending Label Data: " + deviceData.mac);
                agent.send("set.label.data", deviceData);
            }

            // Clear wifi credentials on power cycle
            imp.clearconfiguration();
        }

        @include "AcceleratorTestSuite.device.nut";
        @include "AutodeskDiscKitTesting.device.nut";
}