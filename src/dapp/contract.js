import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';

export default class Contract {
    constructor(network, callback) {

        let config = Config[network];
        console.log(config.url);
        console.log('skata');
        this.web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
        //this.web3 = new Web3(window.web3.currentProvider);
        //let web3Provider = new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws'));
        // this.web3 = new Web3(web3Provider);

        // Is there is an injected web3 instance?
        // if (typeof web3 !== 'undefined') {
        //   //web3 = new Web3(web3.currentProvider);
        // } else {
        //   // If no injected web3 instance is detected, fallback to Ganache.
        //   let web3Provider = new web3.providers.WebsocketProvider(config.url.replace('http', 'ws'));
        //   web3 = new Web3(web3Provider);
        // }
        //
        // web3.eth.getAccounts(function(err, res) {
        //     if (err) {
        //         console.log('Error:',err);
        //         return;
        //     }
        //     console.log('getMetaskID:',res[0]);
        // });
        // if (!web3.currentProvider) {
        //   console.log("teo");
        //   web3.setProvider('http://localhost:8545');
        // }else{
        //   console.log(web3.currentProvider);
        // }
        console.log(config.appAddress);
        this.flightSuretyApp = new this.web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
        this.initialize(callback);
        this.account = null;
        this.airlines = {};
        this.passengers = {};
        this.airlineNames = ['AirAB1','AirAB2','AirAB3','AirAB4','AirAB5'];
        this.passengerNames = ['PAB1','PAB2','PAb3','PAB4','PAb5'];
        this.flights = {
            'AirAB1':['FL1','FL2','FL3'],
            'AirAB2':['AL1','AL2','AL3'],
            'AirAB3':['BL1','BL2','BL3'],
            'AirAB4':['CL1','CL2','CL3'],
            'AirAB5':['DL1','DL2','DL3'],
        }
        /* this.flightSuretyApp.FlightStatusInfo().watch({}, '', function(error, result) {
            if (!error) {
                console.log("Error in transaction");
                console.log("Airline:\n" + result.args.airline) ;
            }
        }) */
    }

    initialize(callback) {

        this.web3.eth.getAccounts((error, accts) => {

            this.account = accts[1];
            console.log('skata'+this.acount);
            let counter = 1;
            let noairline = 0;
            //this.airlines.push(accts[1]);

            //while(this.airlines.length < 5) {
            while(Object.keys(this.airlines).length < 5){
                this.airlines[accts[counter++]] = this.airlineNames[noairline++];
                //this.airlines.push(accts[counter++]);
            }
            noairline = 0;
           // while(this.passengers.length < 5) {
            while(Object.keys(this.passengers).length < 5){
                this.passengers[accts[counter++]] = this.passengerNames[noairline++];
                //this.passengers.push(accts[counter++]);
            }

            callback();
        });

    }

    isOperational(callback) {
       let self = this;
       self.flightSuretyApp.methods
            .isOperational()
            .call({ from: self.account}, callback);
    }

    fetchFlightStatus(airline,flight,timestamp,callback) {
        let self = this;
        let payload = {
            airline: airline,//self.airlines[0],
            flight: flight,
            timestamp: timestamp//Math.floor(Date.now() / 1000)
        }
        //console.log("airline:" + self.airlines[0]) ;
        self.flightSuretyApp.methods
            .fetchFlightStatus(payload.airline, payload.flight, payload.timestamp)
            .send({ from: self.account}, (error, result) => {
                callback(error, result);
            });
    }

    registerAirline(name,address,callback){
        let self = this;
        console.log(self.account);
        console.log(this.account);
        self.flightSuretyApp.methods.registerAirline(name.toString(), address)
        .send({ from: this.account}, (error, result) => {
            callback(error, result);
        });
    }

    sendFunds(airline,funds,callback){
        let self = this;
        const fundstosend = self.web3.utils.toWei(funds, "ether");
        console.log(fundstosend) ;
        self.flightSuretyApp.methods.AirlineFunding()
        .send({ from: airline.toString(),value: fundstosend}, (error, result) => {
            callback(error, result);
        });
    }

    purchaseInsurance(airline,flight,passenger,funds_ether,timestamp,callback){
        let self = this;
        console.log("airline" + airline) ;
        const fundstosend1 = self.web3.utils.toWei(funds_ether, "ether");
        console.log(fundstosend1) ;
        //console.log("passenger buy:" + )
        let ts = timestamp;//1553367808;
        self.flightSuretyApp.methods.registerFlight(airline.toString(),flight.toString(),ts)
        .send({ from: passenger.toString(),value: fundstosend1,gas: 1000000}, (error, result) => {
            callback(error, result);
        });

    }

    withdrawFunds(passenger,funds_ether,callback){
        let self = this;

        const fundstowithdraw = self.web3.utils.toWei(funds_ether, "ether");
        self.flightSuretyApp.methods.withdrawFunds(fundstowithdraw)
        .send({ from: passenger.toString()}, (error, result) => {
            callback(error, result);
        });

    }

    getBalance(passenger,callback){
        let self = this;
        self.flightSuretyApp.methods.getBalance(passenger).call((error, result) => {
            callback(error,result);
        }
    );

    }


}
