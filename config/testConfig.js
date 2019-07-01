
var FlightSuretyApp = artifacts.require("FlightSuretyApp");
var FlightSuretyData = artifacts.require("FlightSuretyData");
var BigNumber = require('bignumber.js');

var Config = async function(accounts) {

    // These test addresses are useful when you need to add
    // multiple users in test scripts
    let testAddresses = [
        "0x69e1CB5cFcA8A311586e3406ed0301C06fb839a2",
        "0xF014343BDFFbED8660A9d8721deC985126f189F3",
        "0x0E79EDbD6A727CfeE09A2b1d0A59F7752d5bf7C9",
        "0x9bC1169Ca09555bf2721A5C9eC6D69c8073bfeB4",
        "0xa23eAEf02F9E0338EEcDa8Fdd0A73aDD781b2A86",
        "0xc449a27b106be1120bd1fd62f8166a2f61588eb9",
        "0xcb0236b37ff19001633e38808bd124b60b1fe1ba",
        "0x715e632c0fe0d07d02fc3d2cf630d11e1a45c522",
        "0x90ffd070a8333acb4ac1b8eba59a77f9f1001819",
        "0x036945cd50df76077cb2d6cf5293b32252bce247",
        "0x23f0227fb09d50477331d2bb8519a38a52b9dfaf",
        "0x799759c45265b96cac16b88a7084c068d38afce9",
        "0xa6bfe07b18df9e42f0086d2fce9334b701868314",
        "0x39ae04b556bbdd73123bab2d091dcd068144361f",
        "0x068729ec4f46330d9af83f2f5af1b155d957bd42",
        "0x9ee19563df46208d4c1a11c9171216012e9ba2d0",
        "0x04ab41d3d5147c5d2bdc3bcfc5e62539fd7e428b",
        "0xef264a86495ff640481d7ac16200a623c92d1e37",
        "0xef264a86495ff640481d7ac16200a623c92d1e37"
    ];


    let owner = accounts[0];
    let firstAirline = accounts[1];
    let firstAirlineName = "Aegean";
    let airlinesInitial = accounts.slice(2, 6);
    let airlinesVoted = accounts.slice(6, 9);
    let passenger = accounts.slice(9,11);
    let oracles = accounts.slice(15, 36); //Here, there are at least 20 oracles;

    let flightSuretyData = await FlightSuretyData.new(firstAirline, {from:owner});
    let flightSuretyApp = await FlightSuretyApp.new(flightSuretyData.address, firstAirlineName, firstAirline);


    return {
        owner: owner,
        firstAirline: firstAirline,
        airlinesInitial: airlinesInitial,
        airlinesVoted: airlinesVoted,
        passenger: passenger,
        oracles: oracles,
        weiMultiple: (new BigNumber(10)).pow(18),
        testAddresses: testAddresses,
        flightSuretyData: flightSuretyData,
        flightSuretyApp: flightSuretyApp
    }
}

module.exports = {
    Config: Config
};
