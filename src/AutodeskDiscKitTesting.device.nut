AutodeskDiscKitTesting = class {

	// NOTE: LED tests are included in this class not the tests class

	static LED_ON = 0;
	static LED_OFF = 1;

    feedbackTimer = null;
    pauseTimer = null;
    done = null;

    accelerator = null;
    tests = null;		
    wiz = null;
    modbus = null;
    adc = null;

    passLED = null;
    failLED = null;
    testsCompleteLED = null;

    failedCount = 0;

	constructor(_feedbackTimer, _pauseTimer, _done) {
        feedbackTimer = _feedbackTimer;
        pauseTimer = _pauseTimer;
        done = _done;

        // assign HAL here 
        accelerator = { "LED_RED" : hardware.pinE,
					    "LED_GREEN" : hardware.pinF,
					    "LED_YELLOW" : hardware.pinG,

					    "GROVE_I2C" : hardware.i2c0,
					    "GROVE_1_D1" : hardware.pinS,
					    "GROVE_1_D2" : hardware.pinM,
					    "GROVE_2_D1" : hardware.pinJ,
					    "GROVE_2_D2" : hardware.pinK,

					    "ADC_SPI" : hardware.spiBCAD,
					    "ADC_CS" : hardware.pinD,

					    "RS485_UART" : hardware.uart1,
					    "RS485_nRE" : hardware.pinL,

					    "WIZNET_SPI" : hardware.spi0,
					    "WIZNET_RESET" : hardware.pinQ,
					    "WIZNET_INT" : hardware.pinH,

					    "USB_EN" : hardware.pinR,
					    "USB_LOAD_FLAG" : hardware.pinW }

		// Configure Hardware
		configureLEDs();
		configureGrove();
        configureWiznet();
		configureModbusRS485();
		configureADC();

        // Initialize Test Class
        tests = AcceleratorTestingFactory.RunDeviceUnderTest.AcceleratorTestSuite();
	}

	// This method runs all tests
	// When testing complete should call done with one param - allTestsPassed (bool)
	function run() {
		pause()
			.then(function(msg) {
				server.log(msg);
				return ledTest();
			}.bindenv(this))
			.then(passed.bindenv(this), failed.bindenv(this))
			.then(function(msg) {
				server.log(msg);
				return tests.wiznetEchoTest(wiz);
			}.bindenv(this))
			.then(passed.bindenv(this), failed.bindenv(this))
			.then(function(msg) {
				server.log(msg);
				return tests.usbFTDITest();
			}.bindenv(this))
			.then(passed.bindenv(this), failed.bindenv(this))
			.then(function(msg) {	
				server.log(msg);
				local deviceAddr = 0x01;
				return tests.RS485ModbusTest(modbus, deviceAddr);
			}.bindenv(this))
			.then(passed.bindenv(this), failed.bindenv(this))		
			.then(function(msg) {	
				server.log(msg);
				local chan = 6;
				local expected = 0;
				local range = 0.2;
				return tests.ADCTest(adc, chan, expected, range);
			}.bindenv(this))
			.then(passed.bindenv(this), failed.bindenv(this))	
			.then(function(msg) {	
				server.log(msg);
				local chan = 7;
				local expected = 2.5; // expecting 2.5
				local range = 0.2;
				return tests.ADCTest(adc, chan, expected, range);
			}.bindenv(this))
			.then(passed.bindenv(this), failed.bindenv(this))								
			.then(function(msg) {
				server.log(msg);
				local tempHumidI2CAddr = 0xBE;
				local whoamiReg = 0x0F;
				local whoamiVal = 0xBC;
				return tests.ic2test(accelerator.GROVE_I2C, tempHumidI2CAddr, whoamiReg, whoamiVal);
			}.bindenv(this))
			.then(passed.bindenv(this), failed.bindenv(this))
			.then(function(msg) {
				server.log(msg);
				return tests.analogGroveTest(accelerator.GROVE_1_D1, accelerator.GROVE_1_D2, accelerator.GROVE_2_D1, accelerator.GROVE_2_D2);
			}.bindenv(this))
			.then(passed.bindenv(this), failed.bindenv(this))
			.then(function(msg) {
				local passing = (failedCount == 0);
				(passing) ? passLED.write(LED_ON) : failLED.write(LED_ON);
				testsCompleteLED.write(LED_ON);
				done(passing); 
			}.bindenv(this))
	}

	// HARDWARE CONFIGURATION HELPERS
	// -----------------------------------------------------------------------------
	function configureLEDs() {
		accelerator.LED_RED.configure(DIGITAL_OUT, LED_OFF);
		accelerator.LED_GREEN.configure(DIGITAL_OUT, LED_OFF);
		accelerator.LED_YELLOW.configure(DIGITAL_OUT, LED_OFF);

		passLED = accelerator.LED_GREEN;
		failLED = accelerator.LED_RED;
		testsCompleteLED = accelerator.LED_YELLOW;
	}

	function configureGrove() {
		accelerator.GROVE_I2C.configure(CLOCK_SPEED_400_KHZ);
		// Grove 1 pins configure as output
		accelerator.GROVE_1_D1.configure(DIGITAL_IN);
		accelerator.GROVE_1_D2.configure(DIGITAL_IN);
		// Grove 2 pins configure as input
		accelerator.GROVE_2_D1.configure(DIGITAL_OUT, 0);
		accelerator.GROVE_2_D2.configure(DIGITAL_OUT, 0);
	}

	function configureADC() {
		local speed = 100;
		local vref = 3.3;
		accelerator.ADC_SPI.configure(CLOCK_IDLE_LOW, speed);
		adc = MCP3208(accelerator.ADC_SPI, vref, accelerator.ADC_CS);
	}

	function configureWiznet() {
		local speed = 1000;
		local spi = accelerator.WIZNET_SPI;
		spi.configure(CLOCK_IDLE_LOW | MSB_FIRST | USE_CS_L, speed);
		wiz = W5500(accelerator.WIZNET_INT, spi, null, accelerator.WIZNET_RESET);
	}

	function configureModbusRS485() {
	    local opts = {};
        opts.baudRate <- 38400;
        opts.parity <- PARITY_ODD;
        modbus = Modbus485Master(accelerator.RS485_UART, accelerator.RS485_nRE, opts);
	}

	// TESTING HELPERS
	// -----------------------------------------------------------------------------

	// Used to space out tests
    function pause(double = false) {
        local pauseTime = (double) ? pauseTimer * 2 : pauseTimer;
        return Promise(function(resolve, reject) {
            imp.wakeup(pauseTime, function() {
                return resolve("Start...");
            });
        }.bindenv(this))
    }

   	function passed(msg) {
   		server.log(msg);
   		return Promise(function (resolve, reject) {
	   		passLED.write(LED_ON);
	   		imp.wakeup(feedbackTimer, function() {
	   			passLED.write(LED_OFF);
	   			imp.wakeup(pauseTimer, function() {
                	return resolve("Start...");
            	});
	   		}.bindenv(this));
   		}.bindenv(this))
	}

	function failed(errMsg) {
   		server.error(errMsg);	
		return Promise(function (resolve, reject) {
	   		failLED.write(LED_ON);
	   		failedCount ++;
	   		imp.wakeup(feedbackTimer, function() {
	   			failLED.write(LED_OFF);
	   			imp.wakeup(pauseTimer, function() {
                	return resolve("Start...");
            	});
	   		}.bindenv(this));
   		}.bindenv(this))
	}

	function ledTest() {
    	server.log("Testing LEDs.");
		// turn LEDs on one at a time
		// then pass a passing test result	
    	return Promise(function (resolve, reject) {
    		failLED.write(LED_ON);
    		imp.wakeup(feedbackTimer, function() {
    			failLED.write(LED_OFF);
    			imp.wakeup(pauseTimer, function() {
    				testsCompleteLED.write(LED_ON);
    				imp.wakeup(feedbackTimer, function() {
    					testsCompleteLED.write(LED_OFF);
    					imp.wakeup(pauseTimer, function() {
    						passLED.write(LED_ON);
    						imp.wakeup(feedbackTimer, function() {
    							passLED.write(LED_OFF);
    							return resolve("LEDs Testing Done.");
    						}.bindenv(this))
    					}.bindenv(this))
    				}.bindenv(this))
    			}.bindenv(this))
    		}.bindenv(this))
    	}.bindenv(this))
    }
}