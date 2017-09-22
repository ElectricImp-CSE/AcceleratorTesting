RunFactoryFixture = class {

    debug = null;

    constructor(_debug) {
        debug = _debug;

        // Handle incomming HTTP requests from DUT
        http.onrequest(HTTPReqHandler.bindenv(this));
        if (debug) server.log("Running Factory Fixture Flow");
    }

    function HTTPReqHandler(req, res) {
        switch (req.method) {
            case "POST":
                try {
                    local data = http.jsondecode(req.body);
                    if ("mac" in data) {
                        // Send the device’s data to the BlinkUp fixture
                        device.send("data.to.print", data);
                        // Confirm successful receipt
                        res.send(200, "OK");
                    } else {
                        // Unexpected request
                        res.send(404, "Not Found");
                    }
                } catch(err) {
                    res.send(400, err);
                }
                break;
            default :
                // Unexpected request
                res.send(404, "Not Found");
        }
    }

}