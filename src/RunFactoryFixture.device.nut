RunFactoryFixture = class {

    static FIXTURE_BANNER = "AD DiscKit Tests";

    // How long to wait (seconds) after triggering BlinkUp before allowing another
    static BLINKUP_TIME = 5;

    // Flag used to prevent new BlinkUp triggers while BlinkUp is running
    sendingBlinkUp = false;

    FactoryFixture_005 = null;
    lcd = null;
    printer = null;

    _ssid = null;
    _password = null;

    constructor(ssid, password) {
        imp.enableblinkup(true);
        _ssid = ssid;
        _password = password;

        // Factory Fixture HAL
        FactoryFixture_005 = {
            "LED_RED" : hardware.pinF,
            "LED_GREEN" : hardware.pinE,
            "BLINKUP_PIN" : hardware.pinM,
            "GREEN_BTN" : hardware.pinC,
            "FOOTSWITCH" : hardware.pinH,
            "LCD_DISPLAY_UART" : hardware.uart2,
            "USB_PWR_EN" : hardware.pinR,
            "USB_FAULT_L" : hardware.pinW,
            "RS232_UART" : hardware.uart0,
            "FTDI_UART" : hardware.uart1,
        }

        // Initialize front panel LEDs to Off
        FactoryFixture_005.LED_RED.configure(DIGITAL_OUT, 0);
        FactoryFixture_005.LED_GREEN.configure(DIGITAL_OUT, 0);

        // Intiate factory BlinkUp on either a front-panel button press or footswitch press
        configureBlinkUpTrigger(FactoryFixture_005.GREEN_BTN);
        configureBlinkUpTrigger(FactoryFixture_005.FOOTSWITCH);

        lcd = CFAx33KL(FactoryFixture_005.LCD_DISPLAY_UART);
        setDefaultDisply();
        configurePrinter();

        // Open agent listener
        agent.on("data.to.print", printLabel.bindenv(this));
    }

    function configureBlinkUpTrigger(pin) {
        // Register a state-change callback for BlinkUp Trigger Pins
        pin.configure(DIGITAL_IN, function() {
            // Trigger only on rising edges, when BlinkUp is not already running
            if (pin.read() && !sendingBlinkUp) {
                sendingBlinkUp = true;
                imp.wakeup(BLINKUP_TIME, function() {
                    sendingBlinkUp = false;
                }.bindenv(this));

                // Send factory BlinkUp
                server.factoryblinkup(_ssid, _password, FactoryFixture_005.BLINKUP_PIN, BLINKUP_FAST | BLINKUP_ACTIVEHIGH);
            }
        }.bindenv(this));
    }

    function setDefaultDisply() {
        lcd.clearAll();
        lcd.setLine1("Electric Imp");
        lcd.setLine2(FIXTURE_BANNER);
        lcd.setBrightness(100);
        lcd.storeCurrentStateAsBootState();
    }

    function configurePrinter() {
        FactoryFixture_005.RS232_UART.configure(9600, 8, PARITY_NONE, 1, NO_CTSRTS, function() {
            server.log(uart.readstring());
        });

        printer = QL720NW(FactoryFixture_005.RS232_UART)
            .setOrientation(QL720NW.PORTRAIT)
            .setFont(QL720NW.FONT_HELSINKI)
            .setFontSize(QL720NW.FONT_SIZE_48);
    }

    function printLabel(data) {
        if (printer == null) configurePrinter();

        printer.setOrientation(QL720NW.PORTRAIT)
            .setFont(QL720NW.FONT_HELSINKI)
            .setFontSize(QL720NW.FONT_SIZE_48);

        if ("mac" in data) {
            // Log mac address
            server.log(data.mac);
            // Add 2D barcode of mac address to label
            printer.write2dBarcode(data.mac, {
                "cell_size": QL720NW.BARCODE_2D_CELL_SIZE_5,
                "symbol_type": QL720NW.BARCODE_2D_SYMBOL_MODEL_2,
                "structured_append_partitioned": false,
                "error_correction": QL720NW.BARCODE_2D_ERROR_CORRECTION_STANDARD,
                "data_input_method": QL720NW.BARCODE_2D_DATA_INPUT_AUTO
            });
            // Add mac address to label
            printer.write(data.mac);
            // Print label
            printer.print();
            // Log status
            server.log("Printed: "+data.mac);
        }
    }
}