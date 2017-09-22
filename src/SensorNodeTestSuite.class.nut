// Sensor Node Test Suite
SensorNodeTestSuite = class {

    // Interrupt settings
    static TEST_WAKE_INT = true;
    static ENABLE_ACCEL_INT = true;
    static ENABLE_PRESS_INT = false;
    static ENABLE_TEMPHUMID_INT = false;

    feedbackTimer = null;
    pauseTimer = null;
    node = null;
    done = null;

    constructor(_feedbackTimer, _pauseTimer, _done) {
        feedbackTimer = _feedbackTimer;
        pauseTimer = _pauseTimer;
        done = _done;
        node = SensorNodeFactory.RunDeviceUnderTest.SensorNodeTests(ENABLE_ACCEL_INT, ENABLE_PRESS_INT, ENABLE_TEMPHUMID_INT, interruptHandler.bindenv(this));
        agent.on("send.test.results", checkTestResults.bindenv(this));
    }

    function checkTestResults(testResults) {
        local passed = testResults.passed.len();
        local failed = testResults.failed.len();
        if (failed > 0) {
            node.testLEDOn(node.led_blue);
        } else {
            node.testLEDOn(node.led_green);
        }
        server.log("Number of tests passed: " + passed);
        server.log("Number of test failed: " + failed);
        server.log("Testing Done.");
        done(failed == 0);
    }

    function run() {
        if (!node.testDone) {
            pause()
                .then(function(result) {
                    if (result.msg) server.log(result.msg);
                    return testLEDs();
                }.bindenv(this))
                .then(function(result) {
                    processTestResult(result);
                    return pause();
                }.bindenv(this))
                // Temp humid sensor test
                .then(function(result) {
                    if (result.msg) server.log(result.msg);
                    return ledFeedback(node.testTempHumid(), "Temp Humid sensor reading");
                }.bindenv(this))
                .then(function(result) {
                    processTestResult(result);
                    return pause();
                }.bindenv(this))
                // Pressure sensor test
                .then(function(result) {
                    if (result.msg) server.log(result.msg);
                    return ledFeedback(node.testPressure(), "Pressure sensor reading");
                }.bindenv(this))
                .then(function(result) {
                    processTestResult(result);
                    return pause();
                }.bindenv(this))
                // Accel sensor test
                .then(function(result) {
                    if (result.msg) server.log(result.msg);
                    return ledFeedback(node.testAccel(), "Accel sensor reading");
                }.bindenv(this))
                .then(function(result) {
                    processTestResult(result);
                    return pause();
                }.bindenv(this))
                // Onwire discovery test
                .then(function(result) {
                    if (result.msg) server.log(result.msg);
                    return ledFeedback(node.testOnewire(), "OneWire discovery");
                }.bindenv(this))
                .then(function(result) {
                    processTestResult(result);
                    return pause();
                }.bindenv(this))
                // Onewire i2c test
                .then(function(result) {
                    if (result.msg) server.log(result.msg);
                    local sensors = node.scanRJ12I2C();
                    return ledFeedback(sensors.find(0x80) != null, "OneWire I2C scan");
                }.bindenv(this))
                .then(function(result) {
                    processTestResult(result);
                    // give time to process i2c scan before going to sleep
                    local doublePauseLength = true;
                    return pause(doublePauseLength);
                }.bindenv(this))
                .then(function(result) {
                    if (result.msg) server.log(result.msg);
                    server.log("Test low power. Then wake by tossing");
                    // configure interrupt, and sleep
                    node.testInterrupts(TEST_WAKE_INT)
                }.bindenv(this))
        }
    }

    function pause(double = false) {
        local pauseTime = (double) ? pauseTimer * 2 : pauseTimer;
        return Promise(function(resolve, reject) {
            imp.wakeup(pauseTime, function() {
                return resolve({"err" : null, "msg" : "Starting next test..."})
            });
        }.bindenv(this))
    }

    function processTestResult(result) {
        if (result.err) server.error(result.err);
        if (result.msg) server.log(result.msg);
        agent.send("test.result", result);
    }

    function interruptHandler(intTable) {
        if ("int1" in intTable) {
            imp.wakeup(0, function() {
                ledFeedback(true, "Freefall detected")
                    .then(function(result) {
                        processTestResult(result);
                        return pause();
                    }.bindenv(this))
                    .then(function(result) {
                        server.log("Checking test results...");
                        agent.send("get.test.results", null);
                    }.bindenv(this))
            }.bindenv(this))
        }
    }

    function testLEDs() {
        return Promise(function(resolve, reject) {
            // Green LED on
            node.testLEDOn(node.led_green);
            imp.wakeup(feedbackTimer, function() {
                // Green LED off
                node.testLEDOff(node.led_green);
                imp.wakeup(pauseTimer, function() {
                    // Blue LED on
                    node.testLEDOn(node.led_blue);
                    imp.wakeup(feedbackTimer, function() {
                        // Blue led off
                        node.testLEDOff(node.led_blue);
                        return resolve({"err" : null, "msg" : "LED Tesing Passed"});
                    }.bindenv(this));
                }.bindenv(this))
            }.bindenv(this));
        }.bindenv(this))
    }

    function ledFeedback(testResult, sensorMsg) {
        return Promise(function (resolve, reject) {
            local err = null;
            local msg = null;
            if (testResult) {
                // Green LED on
                node.testLEDOn(node.led_green);
                msg = sensorMsg + " test passed";
            } else {
                // Blue LED on
                node.testLEDOn(node.led_blue);
                err = sensorMsg + " test failed"
            }
            imp.wakeup(feedbackTimer, function() {
                node.testLEDOff(node.led_green);
                node.testLEDOff(node.led_blue);
                return resolve({"err" : err, "msg" : msg});
            }.bindenv(this));
        }.bindenv(this));
    }
}
