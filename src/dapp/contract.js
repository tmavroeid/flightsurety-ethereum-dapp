import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import FlightSuretyData from '../../build/contracts/FlightSuretyData.json';

import Config from './config.json';
import Web3 from 'web3';

export default class Contract {
    constructor(network, callback) {
          let config = Config[network];

          if (window.ethereum) {
            // use metamask's providers
            // modern browsers
            console.log("Modern Browser");
            this.web3 = new Web3(window.ethereum)
            // Request accounts access
            try {
              window.ethereum.enable()
            } catch (error) {
              console.error('User denied access to accounts')
            }
          } else if (window.web3) {
            // legacy browsers
            console.log("Legacy Browsers");
            this.web3 = new Web3(web3.currentProvider)
          } else {
            // fallback for non dapp browsers
            this.web3 = new Web3(new Web3.providers.HttpProvider(config.url))
          }

        // Load contract
        this.flightSuretyApp = new this.web3.eth.Contract(FlightSuretyApp.abi, config.appAddress)
        this.flightSuretyData = new this.web3.eth.Contract(FlightSuretyData.abi, config.dataAddress)
        this.initialize(callback)
        this.account = null


        console.log("The appAddress is: "+config.appAddress);
        //this.flightSuretyApp = new this.web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
        //this.initialize(callback);
        //this.account = null;
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
            if (!error) {
              this.account = accts[0]
              console.log("This account is: "+this.account)
              // let counter = 1;
              // let noairline = 0;
              // //this.airlines.push(accts[1]);
              //
              // //while(this.airlines.length < 5) {
              // while(Object.keys(this.airlines).length < 5){
              //     this.airlines[accts[counter++]] = this.airlineNames[noairline++];
              //     //this.airlines.push(accts[counter++]);
              // }
              // noairline = 0;
              // // while(this.passengers.length < 5) {
              // while(Object.keys(this.passengers).length < 5){
              //     this.passengers[accts[counter++]] = this.passengerNames[noairline++];
              //     //this.passengers.push(accts[counter++]);
              // }
              callback()
            } else {
              console.error(error)
            }
        })
        // this.web3.eth.getAccounts((error, accts) => {
        //
        //     this.account = accts[1];
        //     console.log('skata'+this.acount);
        //     let counter = 1;
        //     let noairline = 0;
        //     //this.airlines.push(accts[1]);
        //
        //     //while(this.airlines.length < 5) {
        //     while(Object.keys(this.airlines).length < 5){
        //         this.airlines[accts[counter++]] = this.airlineNames[noairline++];
        //         //this.airlines.push(accts[counter++]);
        //     }
        //     noairline = 0;
        //    // while(this.passengers.length < 5) {
        //     while(Object.keys(this.passengers).length < 5){
        //         this.passengers[accts[counter++]] = this.passengerNames[noairline++];
        //         //this.passengers.push(accts[counter++]);
        //     }
        //
        //     callback();
        // });

    }

    isOperational(callback) {
       let self = this;
       self.flightSuretyApp.methods
            .isOperational()
            .call({ from: this.account}, callback);
    }

    fetchFlightStatus(airline,flight,timestamp,callback) {
        let self = this;
        let payload = {
            airline: airline,//self.airlines[0],
            flight: flight,
            timestamp: timestamp//Math.floor(Date.now() / 1000)
        }
        //console.log("airline:" + self.airlines[0]) ;
        self.flightSuretyApp.methods.fetchFlightStatus(payload.airline, payload.flight, payload.timestamp)
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

    fundingAirline(address, funds, callback){
      let self = this;
      console.log(self.account);
      console.log(this.account);
      self.flightSuretyApp.methods.fundingAirline()
      .send({ from: address, value: funds}, (error, result) => {
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

    purchaseInsurance(airline,flight,takeofftimestamp,fee,callback){
        let self = this;
        self.flightSuretyApp.methods.purchaseFlightInsurance(airline.toString(),flight.toString(),takeofftimestamp)
        .send({ from: this.account ,value: fee, gas: 1000000}, (error, result) => {
            callback(error, result);
        });

    }

    withdrawFunds(airline,flight,ts,callback){
        let self = this;
        self.flightSuretyApp.methods.withdrawFunds(airline,flight,ts)
        .send({ from: this.account}, (error, result) => {
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

    registerFlight(airline, flightname, ts, destination, arrival, ticketprice,callback){
      let self = this;
      self.flightSuretyApp.methods.registerFlight(airline, flightname, ts, destination, arrival, ticketprice).send({ from: this.account} ,(error, result) => {
          callback(error,result);
      }
    );
    }


}
