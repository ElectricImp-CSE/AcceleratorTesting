class MCP3208 {

	static MCP3208_STARTBIT      = 0x10;
    static MCP3208_SINGLE_ENDED  = 0x08;
    static MCP3208_DIFF_MODE     = 0x00;

    static MCP3208_CHANNEL_0     = 0x00;
    static MCP3208_CHANNEL_1     = 0x01;
    static MCP3208_CHANNEL_2     = 0x02;
    static MCP3208_CHANNEL_3     = 0x03;
    static MCP3208_CHANNEL_4     = 0x04;
    static MCP3208_CHANNEL_5     = 0x05;
    static MCP3208_CHANNEL_6     = 0x06;
    static MCP3208_CHANNEL_7     = 0x07;

    _spi = null;
	_csPin = null;
	_vref = null;

	function constructor(spi, vref, cs = null) { 
		_spi = spi;
		_vref = vref;
		_csPin = cs;
		if (_csPin) _csPin.configure(DIGITAL_OUT, 1);
	}
	
	function readADC(channel) { 

		(_csPin == null) ? _spi.chipselect(1) : _csPin.write(0);
		
        // 3 byte command
        local sent = blob();
        sent.writen(0x06 | (channel >> 2), 'b');
        sent.writen((channel << 6) & 0xFF, 'b');
        sent.writen(0, 'b');
        
        local read = _spi.writeread(sent);

        (_csPin == null) ? _spi.chipselect(0) : _csPin.write(1);

        // Extract reading as volts
        local reading = ((((read[1] & 0x0f) << 8) | read[2]) / 4095.0) * _vref;
        
        return reading;
	}

	function readDifferential(in_minus, in_plus) {

	    (_csPin == null) ? _spi.chipselect(1) : _csPin.write(0);
	    
	    local select = in_plus; // datasheet
	    local sent = blob();
	    
	    sent.writen(0x04 | (select >> 2), 'b'); // only difference b/w read single
	    // and read differential is the bit after the start bit
        sent.writen((select << 6) & 0xFF, 'b');
        sent.writen(0, 'b');
	    
	    local read = _spi.writeread(sent);

	    (_csPin == null) ? _spi.chipselect(0) : _csPin.write(1);
	    
	    local reading = ((((read[1] & 0x0f) << 8) | read[2]) / 4095.0) * _vref;
	    return reading;
	}
}


/*
local spi = hardware.spi0;
local cs = null;
local speed = 1000;
local vref = 3.3;

// if needed configure power enable pin for the ADC

spi.configure(CLOCK_IDLE_LOW | MSB_FIRST | USE_CS_L, speed);
local adc = MCP3208(accelerator.ADC_SPI, vref, cs);

while(true) {
    server.log(format("reading: %.2f v", myADC.readADC(1)));
    server.log(format("difference: %.2f v", myADC.readDifferential(0, 1)));
    imp.sleep(1);
}


*/