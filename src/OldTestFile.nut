#require "W5500.device.nut:1.0.0"
//#require "UsbHost.device.lib.nut:1.0.0"
//#require "FtdiUsbDriver.device.lib.nut:1.0.0"
//#require "UartOverUsbDriver.device.lib.nut:1.0.0"

  
// Fieldbus Hardware Abstraction Layer
FieldbusGateway_005 <- {
    "LED_RED" : hardware.pinP,
    "LED_GREEN" : hardware.pinT,
    "LED_YELLOW" : hardware.pinQ,

    "MIKROBUS_AN" : hardware.pinM,
    "MIKROBUS_RESET" : hardware.pinH,
    "MIKROBUS_SPI" : hardware.spiBCAD,
    "MIKROBUS_PWM" : hardware.pinU,
    "MIKROBUS_INT" : hardware.pinXD,
    "MIKROBUS_UART" : hardware.uart1,
    "MIKROBUS_I2C" : hardware.i2cJK,

    "XBEE_RESET" : hardware.pinH,
    "XBEE_AND_RS232_UART": hardware.uart0,
    "XBEE_DTR_SLEEP" : hardware.pinXD,

    "RS485_UART" : hardware.uart2,
    "RS485_nRE" : hardware.pinL,

    "WIZNET_SPI" : hardware.spi0,
    "WIZNET_RESET" : hardware.pinXA,
    "WIZNET_INT" : hardware.pinXC,

    "USB_EN" : hardware.pinR,
    "USB_LOAD_FLAG" : hardware.pinW
}

local wiznetTest = false;
local wiznetTestStr = "SOMETHING"
local UNLIT = 1;
local LIT = 0;



/////////////////////////
// USB
////////////////////////

function sendTestData(device) {
    server.log("sending test data.")
    device.write("I'm a Blob\n");
    imp.wakeup(10, function() {
        sendTestData(device)
    });
}

function onConnected(device) {
    device.on("data", dataEvent);
    server.log(typeof device);
    switch (typeof device) {
        case "UartOverUsbDriver":
            printer <- QL720NW(device);
            server.log("Created printer using uartoverusb")

            printer
                .setOrientation(QL720NW.LANDSCAPE)
                .setFont(QL720NW.FONT_SAN_DIEGO)
                .setFontSize(QL720NW.FONT_SIZE_48)
                .write("San Diego 48 ")
                .print();

            
            barcodeConfig <- {
                "type": QL720NW.BARCODE_CODE39,
                "charsBelowBarcode": true,
                "width": QL720NW.BARCODE_WIDTH_M,
                "height": 1,
                "ratio": QL720NW.BARCODE_RATIO_3_1
            }

            printer.writeBarcode(imp.getmacaddress(), barcodeConfig).print();
            break;
        case "FtdiUsbDriver":
            sendTestData(device);
            break;
    }
}

function dataEvent(eventDetails) {
    server.log("got data on usb: " + eventDetails);
}

function onDisconnected(devicetype) {
    server.log(devicetype + " disconnected");
}

function readback() {

    dataString += uart.readstring();
    if (dataString.find("\n")) {
        server.log("Recieved data on UART [" + dataString + "] Sending data back to USB");
        logs.write("Hi from UART");
        dataString = "";
    }

}


uart <- hardware.uart1;
dataString <- "";

FieldbusGateway_005.USB_LOAD_FLAG.configure(DIGITAL_IN);

FieldbusGateway_005.USB_EN.configure(DIGITAL_OUT, 1);

//usbHost <- UsbHost(hardware.usb);

//usbHost.registerDriver(FtdiUsbDriver, FtdiUsbDriver.getIdentifiers());



vid <- 0x04f9;
pid <- 0x2044;
identifier <- {};
identifier[vid] <- pid;
identifiers <- [identifier]
//usbHost.registerDriver(UartOverUsbDriver, identifiers);


//usbHost.on("connected", onConnected);


//uart.configure(115200, 8, PARITY_NONE, 1, 0, readback);
//logs <- UartLogger(uart);




/////////////////////////
// WIZNET
/////////////////////////
//================================================
// RUN
//================================================

function readyCb() {

    // Connection settings
    local destIP   = "192.168.201.3";
    local destPort = 4242;

    local started = hardware.millis();

    server.log("Attemping to connect via LAN...");
 //   server.log(server.log("isReady "+ wiz._isReady))
    wiz.configureNetworkSettings("192.168.201.2", "255.255.255.0", "192.168.201.1");
    wiz.openConnection(destIP, destPort, function(err, connection) {

        local dur = hardware.millis() - started;
        if (err) {
            server.error(format("Connection failed to %s:%d in %d ms: %s", destIP, destPort, dur, err.tostring()));
            imp.wakeup(30, function() {
                wiz.onReady(readyCb);
            })
            return;
        }

        //server.log(format("Connection to %s:%d in %d ms", destIP, destPort, dur));

        // Create event handlers for this connection
        connection.onReceive(receiveCb);
        connection.onDisconnect(disconnectCb);

        // Receive the response
        connection.receive(function(err, data) {
            
            local response_str = "";
            data.seek(0, 'b');
            response_str = data.readstring(9);
            local index = 80;
        
            //index = response_str.find(wiznetTestStr); 
        
            if (response_str.find(wiznetTestStr) != null){
                server.log("Expected response seen!!!!!!");
                wiznetTest = true;
            } else {
                if(wiznetTest == false){
                    server.log("LAN comms not established");
                }
            
            //    server.log(response_str);
            }
       
       
       //     server.log(format("Manual response from %s:%d: " + data, this.getIP(), this.getPort()));
        })

        // Send data over the connection
        local send;
        send = function() {
        //    server.log("Sending ...");
            connection.transmit(wiznetTestStr, function(err) {
                if (err) {
                    server.error("Send failed, closing: " + err);
                    connection.close();
                } else {
     //               server.log(format("Sent successful to %s:%d", destIP, destPort));
                    imp.wakeup(10, send.bindenv(this));
                }
            }.bindenv(this));
        }
        send();

    }.bindenv(this));

}

function receiveCb(err, response) {
 
//         server.log(response);
         
    local response_str = "";

    response.seek(0, 'b');
 
    response_str = response.readstring(9);
    
    
    local index = 80;
    
    index = response_str.find(wiznetTestStr); 
    
    if (index != null){
        if(wiznetTest == false){
            server.log("Expected response seen!!!!!!");
            wiznetTest = true;
        }
    }
    else {
        if(wiznetTest == false){
            server.log("LAN comms not established");
        }
        
    //    server.log(response_str);
    }
    
//    server.log(format("Catchall response from %s:%d: " + response, this.getIP(), this.getPort()));
}

function disconnectCb(err) {
    server.log(format("Disconnection from %s:%d", this.getIP(), this.getPort()));
    imp.wakeup(30, function() {
        wiz.onReady(readyCb);
    })
}

// Initialise the LEDS
FieldbusGateway_005.LED_RED.configure(DIGITAL_OUT, UNLIT);
FieldbusGateway_005.LED_YELLOW.configure(DIGITAL_OUT, UNLIT);
FieldbusGateway_005.LED_GREEN.configure(DIGITAL_OUT, UNLIT);

// Initialise SPI port
wiznet_test <- false;
spiSpeed     <- 1000;
FieldbusGateway_005.WIZNET_SPI.configure(CLOCK_IDLE_LOW | MSB_FIRST | USE_CS_L, spiSpeed);

started <- hardware.millis();

// Initialise Wiznet
wiz <- W5500(FieldbusGateway_005.WIZNET_INT, FieldbusGateway_005.WIZNET_SPI, null, FieldbusGateway_005.WIZNET_RESET);

// Wait for Wiznet to be ready before opening connections
//server.log("Waiting for Wiznet to be ready ...");
wiz.onReady(readyCb);
