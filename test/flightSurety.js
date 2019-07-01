
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');
var num = 3;
var n = num.toString();
const registrationPrice = web3.utils.toWei(n, "ether")
const expectedRegistrationFee = web3.utils.toWei('10', 'ether');
const timestamp = Math.floor(Date.now() / 1000) + 1000;
const arrival = timestamp + 3000;
const destination = "Budapest";
const ticketprice = web3.utils.toWei('2', 'ether');
const insuranceAmount = web3.utils.toWei('0.7', 'ether');
const registrationFee = web3.utils.toWei('1', 'ether');
const payout = 868640000000000;
let index;
contract('Flight Surety Tests', async (accounts) => {
  const truffleAssert = require('truffle-assertions');
  var config;
  before('setup contract', async () => {
    config = await Test.Config(accounts);
    await config.flightSuretyData.authorizeCallerContract(config.flightSuretyApp.address);
  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/
  describe(`\n✈️  Airlines ✈️ :`, async() => {
  it('(airline) is firstAirline registered with the deployment of the contracts', async () => {


    let result = await config.flightSuretyData.isAirlineRegistered.call(config.firstAirline);

    // ASSERT
    assert.equal(result, true, "firstAirline has not been registered with the deployment of the contract");

  });

  it('(airline) firstAirline is not funded with the deployment of the contracts', async () => {


    let result = await config.flightSuretyData.isAirlineFunded.call(config.firstAirline);

    // ASSERT
    assert.equal(result, false, "firstAirline has not been funded with the deployment of the contract");

  });

  it('(airline) Airline can provide funding', async () => {
    let balanceBefore = await web3.eth.getBalance(config.flightSuretyData.address);
    //console.log(balanceBefore);
    try {
      await config.flightSuretyApp.fundingAirline({ from: config.firstAirline, value: expectedRegistrationFee });
    }catch(e) {
         console.log(e);
    }
    const result = await config.flightSuretyData.isAirlineFunded.call(config.firstAirline);
    assert.equal(result, true, "Airline has not provided funding yet or process of funding failed to complete successfully");
    let balanceAfter = await web3.eth.getBalance(config.flightSuretyData.address);
    //console.log(balanceAfter)
    assert.equal(+balanceBefore + expectedRegistrationFee, +balanceAfter, 'Error: 10 ETH should have been transfered');
  });

  it('(airline) Airline can register another Airline using registerAirline() (when multi-party is not reached)', async () => {

    // ARRANGE
    let newAirline = config.airlinesInitial[0];

    // ACT
    try {
        await config.flightSuretyApp.registerAirline("Ryanair", newAirline, {from: config.firstAirline});
    }
    catch(e) {
      console.log(e);
    }
    let result = await config.flightSuretyData.isAirlineRegistered.call(newAirline);
    // ASSERT
    assert.equal(result, true, "New Airline did not register successfully");
  });

  it('(airline) Second Airline funded and Third Airline successful registration and funding (when multi-party is not reached)', async () => {

    // ARRANGE
    let newAirline = config.airlinesInitial[0];
    let thirdAirline = config.airlinesInitial[1];


    // ACT
    try {
        await config.flightSuretyApp.fundingAirline({ from: newAirline, value: expectedRegistrationFee });
        let result = await config.flightSuretyData.isAirlineFunded.call(newAirline);

        await config.flightSuretyApp.registerAirline("Emirates", thirdAirline, {from: config.firstAirline});

        await config.flightSuretyApp.fundingAirline({ from: thirdAirline, value: expectedRegistrationFee });
    }
    catch(e) {
      console.log(e);
    }
    let res = await config.flightSuretyData.isAirlineRegistered.call(thirdAirline);
    let result = await config.flightSuretyData.isAirlineFunded.call(thirdAirline);
    // ASSERT
    assert.equal(res, true, "Third Airline did not register successfully");
    assert.equal(result, true, "Third Airline did not funded successfully");

  });

  it('(airline) 4 Airlines can register another Airline using registerAirline() (multi-party consensus)', async () => {

      let fourthAirline = config.airlinesInitial[2];
      let thirdAirline = config.airlinesInitial[1];
      let fifthAirline = config.airlinesVoted[0];

      try{
          await config.flightSuretyApp.registerAirline("Lufthansa", fourthAirline, {from: config.firstAirline});
          await config.flightSuretyApp.fundingAirline({ from: fourthAirline, value: expectedRegistrationFee });

          let res = await config.flightSuretyData.isAirlineFunded.call(fourthAirline);
          assert.equal(res, true, "Fourth Airline not funded yet");

          await config.flightSuretyApp.registerAirline("Qatar Airways", fifthAirline, {from: config.firstAirline});

          await config.flightSuretyApp.registerAirline("Qatar Airways", fifthAirline, {from: thirdAirline});

          let num = await config.flightSuretyApp.numRegistered.call();
          //console.log("The number of already registered Airlines is: "+num.toString());

          //let votes = await config.flightSuretyApp.votes(fifthAirline);
          //console.log("The votes for the fifth Airline are: "+votes.toString());

          //await config.flightSuretyApp.fundingAirline({ from: fifthAirline, value: expectedRegistrationFee });



      }
      catch(e) {
        console.log(e);
      }
      let result_registration = await config.flightSuretyData.isAirlineRegistered.call(fifthAirline);
      assert.equal(result_registration, true, "Fifth Airline did not register successfully");
      //let result_funding = await config.flightSuretyData.isAirlineFunded.call(fifthAirline);
      //assert.equal(result_funding, true, "Fifth Airline did not funded successfully");
    });


});

  // it('(airline) can provide funding using fundingAirline() if it is not funded yet', async () => {
  //
  //
  //   // ACT
  //   try {
  //       console.log("kala")
  //       await config.flightSuretyApp.fundingAirline({from: config.firstAirline, value: expectedRegistrationFee});
  //   }
  //   catch(e) {
  //     console.log(e);
  //   }
  //   let result = await config.flightSuretyData.isAirlineFunded.call(config.firstAirline);
  //   console.log(result);
  //   assert.equal(result, true, "Airline has not provided funding yet or process of funding failed to complete successfully");
  //   // let balance = web3.eth.getBalance(config.flightSuretyData.address).toNumber();
  //   // var m = balance.toString();
  //   // let balanceToEther = web3.utils.fromWei(m, 'ether').toString()
  //   //console.log(balanceToEther);
  //
  //   // await web3.utils.fromWei(web3.eth.getBalance(config.flightSuretyData.address).toString(),"ether").then(result=>{
  //   //   console.log(result);
  //   // }).catch(error=>{
  //   //   console.log(error);
  //   // })
  //
  //   //let balanceToEther = web3.utils.fromWei(balance,"ether").toString();
  //
  //   console.log("skata2");
  //
  //
  //
  //   // ASSERT
  //
  // });




  describe(`\n✈️  Flights & Passengers ✈️ :`, async() => {
    it('(flights) Airline can register a flight', async () => {

      let secondAirline = config.airlinesInitial[0];
      try{

        let tx = await config.flightSuretyApp.registerFlight(secondAirline, "Athens - Budapest", timestamp, destination, arrival, ticketprice,  { from: secondAirline });
        let flightkey = await config.flightSuretyApp.getFlightKey(secondAirline, "Athens - Budapest", timestamp);

        let flight = await config.flightSuretyData.flights.call(flightkey);
        assert.equal(flight.isRegistered, true, 'Flight was not registered successfully');

        truffleAssert.eventEmitted(tx, 'FlightRegistered', res => {
            return res.flightkey === flightkey
          });



      }catch(e){
        console.log(e);
      }

      });

      it('(passenger) Passenger can buy insurance for a flight', async () => {
        let balanceBefore = await web3.eth.getBalance(config.flightSuretyData.address);
        let secondAirline = config.airlinesInitial[0];
        let passenger = config.passenger[0];
        let passengerBalanceBefore = await web3.eth.getBalance(passenger);
        try{
          let tx = await config.flightSuretyApp.purchaseFlightInsurance(secondAirline, "Athens - Budapest", timestamp, {from: passenger, value: insuranceAmount})
          let passengerGotInsurance = await config.flightSuretyData.getInsuree(passenger);
          assert.equal(passengerGotInsurance, true, 'Passenger was not get insurance successfully');
          truffleAssert.eventEmitted(tx, 'PassengerInsured', res => {
              return res.passenger === passenger
          });
          // let skata = await config.flightSuretyApp.getAmount(secondAirline, "Athens - Budapest",timestamp, {from: passenger});
          // console.log(skata)

        }catch(e){
          console.log(e);
        }
        let balanceAfter = await web3.eth.getBalance(config.flightSuretyData.address);
        let passengerBalanceAfter = await web3.eth.getBalance(passenger);
        let passenger_difference = passengerBalanceAfter - passengerBalanceBefore;

        let difference = balanceAfter - balanceBefore;
        // console.log(balanceBefore);
        // console.log(balanceAfter);
        // console.log(insuranceAmount);
        // console.log(difference);
        //
        // console.log(passengerBalanceBefore);
        // console.log(passengerBalanceAfter);
        // console.log(passenger_difference);

        assert.equal( insuranceAmount,difference, 'Error: the insurance amount paid from the passenger isnot transefered');
        });
  });

  describe(`\n✈️  Oracles & Passengers ✈️ :`, async() => {
      it('(oracles) Oracles can register', async () => {
        let n = 20;

        try{
          for(let a=1; a<n; a++) {
              await config.flightSuretyApp.registerOracle({ from: config.oracles[a], value: registrationFee });
              let result = await config.flightSuretyApp.getOracle.call(config.oracles[a]);
              //console.log(`Oracle: ${result[0]}, ${result[1]}, ${result[2]}`);
          }
        }catch(e){
          //console.log(e);
        }

        });

        // it('(oracles) Can request flight status', async () => {
        //
        //     // ARRANGE
        //     let flight = "Athens - Budapest"; // Course number
        //     let n = 20;
        //     let secondAirline = config.airlinesInitial[0];
        //     let tx = await config.flightSuretyApp.fetchFlightStatus(secondAirline, flight, timestamp);
        //     truffleAssert.eventEmitted(tx,'OracleRequest', ev => {
        //         console.log(`OracleRequest: index ${+ev.index}, airline ${ev.airline}, flight ${ev.flightName}, timestamp ${+ev.takeoffTimestamp}, isOpen ${ev.isOpen}, key ${ev.key}`);
        //         return ev.airline === secondAirline & ev.flightName === flight & +ev.takeoffTimestamp === timestamp & ev.isOpen === true;
        //     },'OracleRequest event test: wrong event/event args');
        //     console.log("skata34");
        //
        //     // ACT
        //     // Since the Index assigned to each test account is opaque by design
        //     // loop through all the accounts and for each account, all its Indexes (indices?)
        //     // and submit a response. The contract will reject a submission if it was
        //     // not requested so while sub-optimal, it's a good test of that feature
        //     for(let a=1; a<n; a++) {
        //       // Submit a request for oracles to get status information for a flight
        //       //console.log(tx);
        //
        //       // Get oracle information
        //       // For a real contract, we would not want to have this capability
        //       // so oracles can remain secret (at least to the extent one doesn't look
        //       // in the blockchain data)
        //       let oracleIndexes = await config.flightSuretyApp.getOracle.call(config.oracles[a]);
        //       console.log(`Oracle: ${oracleIndexes[0]}, ${oracleIndexes[1]}, ${oracleIndexes[2]}`);
        //
        //       for(let idx=0;idx<3;idx++) {
        //
        //         try {
        //           console.log(oracleIndexes[idx].toString());
        //           // Submit a response...it will only be accepted if there is an Index match
        //           // let oraclereq = await config.flightSuretyApp.getKey(oracleIndexes[idx], secondAirline, flight, timestamp);
        //           //
        //           // truffleAssert.eventEmitted(oraclereq,'isKey', ev => {
        //           //     console.log(`${ev.key}`);
        //           // }).catch(e=>{
        //           //   console.log(e);
        //           // });
        //
        //           // let isopen = await config.flightSuretyApp.getIsOpen(oracleIndexes[idx], secondAirline, flight, timestamp, 10);
        //           // console.log(isopen);
        //
        //           console.log("skatoules");
        //           let oracleres = await config.flightSuretyApp.submitOracleResponse(oracleIndexes[idx], secondAirline, flight, timestamp, 10, { from: config.oracles[a] });
        //
        //           truffleAssert.eventEmitted(oracleres,'OracleReport ', ev => {
        //             console.log("all good!");
        //             return ev.airline === secondAirline & ev.flightName === flight & +ev.takeoffTimestamp === timestamp;
        //           }).catch(e =>{
        //             console.log(e);
        //           });
        //           console.log("skatoules5");
        //
        //           truffleAssert.eventEmitted(oracleres,'FlightStatusInfo ', ev => {
        //             console.log(`all good2! ${+ev.verified}`);
        //
        //             return ev.airline === secondAirline & ev.flightName === flight & +ev.takeoffTimestamp === timestamp & ev.verified ===true;
        //           }).catch(e =>{
        //             console.log(e);
        //           });
        //           console.log("skata");
        //           // Check to see if flight status is available
        //           // Only useful while debugging since flight status is not hydrated until a
        //           // required threshold of oracles submit a response
        //           let flightStatus = await config.flightSuretyApp.viewFlightStatus(oracleIndexes[idx], secondAirline, flight, timestamp);
        //           console.log('\nPost', idx, oracleIndexes[idx], flight, timestamp, flightStatus);
        //         }catch(e) {
        //           // Enable this when debugging
        //           //console.log('\nError', idx, oracleIndexes[idx].toNumber(), secondAirline, flight, timestamp);
        //           console.log(e);
        //         }
        //
        //       }
        //     }
        //
        //
        //   });
        it('(oracles) Can request flight status, process it and credit insuree', async () => {
            let flight = "Athens - Budapest"; // Course number
            let n = 20;
            let secondAirline = config.airlinesInitial[0];
            let passenger = config.passenger[0];
            let tx;
            // Submit a request for oracles to get status information for a flight
            const tax = await config.flightSuretyApp.fetchFlightStatus(secondAirline, flight, timestamp)
            truffleAssert.eventEmitted(
              tax,
              'OracleRequest',
              ev => {
                console.log(`OracleRequest: index ${+ev.index}, airline ${ev.airline}, flight ${ev.flight}, timestamp ${+ev.timestamp}, isOpen ${ev.isOpen}, key ${ev.key}`);
                index = ev.index;
                return ev.airline === secondAirline & ev.flight === flight & +ev.timestamp === timestamp & ev.isOpen === true;

              },
              'OracleRequest event test: wrong event/event args')

            /* Since the Index assigned to each test account is opaque by design, loop through all the accounts and for each account, all its Indexes (indices?) and submit a response. The contract will reject a submission if it was not requested so while sub-optimal, it's a good test of that feature
            */
            for (let a = 1; a < n; a++) {
              // Get oracle information
              //let oracleIndexes = await config.flightSuretyApp.getMyIndexes.call({ from: config.oracles[a] })
              let oracleIndexes = await config.flightSuretyApp.getOracle.call(config.oracles[a]);
              //console.log(`Oracle: ${oracleIndexes[0]}, ${oracleIndexes[1]}, ${oracleIndexes[2]}`);
              for (let idx = 0; idx < 3; idx++) {
                try {
                  // Submit a response...it will only be accepted if there is an Index match
                  tx = await config.flightSuretyApp.submitOracleResponse(
                    oracleIndexes[idx],
                    secondAirline,
                    flight,
                    timestamp,
                    20,
                    { from: config.oracles[a] });

                  // Check OracleReport event, emitted if index match
                  truffleAssert.eventEmitted(
                    tx,
                    'OracleReport',
                    ev => {
                      //console.log(`OracleReport: flight ${ev.flight}, destination ${ev.destination}, timestamp ${+ev.timestamp}`)
                      //console.log("OracleReport Event");
                      return ev.airline == secondAirline & ev.flight == flight & +ev.timestamp == timestamp & +ev.status == 20;
                    });

                  // FlightStatusInfo: emitted when threshold of same responses is reached
                  truffleAssert.eventEmitted(
                    tx,
                    'FlightStatusInfo',
                    ev => {
                      //console.log("FlightStatusInfo Event");
                      return ev.airline == secondAirline & ev.flight == flight & +ev.timestamp == timestamp;
                    },
                    'FlightStatusInfo event test: wrong event/event args'
                  );


                } catch (error) {
                 //console.log(error.message)
               }

             }

            }
            truffleAssert.eventEmitted(tx, 'FlightProcessed', ev => {
              console.log(`FlightProcessed`);
              return ev.flight == flight &  ev.timestamp == timestamp & ev.statusCode == 20;
            }, 'FlightProcessed event test: wrong event/event args');

            let x = await config.flightSuretyApp.getBalance.call(passenger);
            //console.log(x.toString());
            let y = await web3.eth.getBalance(passenger);
            //console.log(y.toString());

          });

          it('(oracles) Examine the Request after adequate answers have been received', async () => {
            let flight = "Athens - Budapest";
            let secondAirline = config.airlinesInitial[0];
            const key = await config.flightSuretyApp.getFlightKeyWithIndex(index, secondAirline, flight, timestamp);
            //console.log(key);
            const request = await config.flightSuretyApp.oracleResponses(key);
            assert(!request.isOpen, 'Request should be closed');
          });

          it('(oracles) Update Flight StatusCode after adequate answers have been received', async () => {
            let flight = "Athens - Budapest";
            let secondAirline = config.airlinesInitial[0];
            const key = await config.flightSuretyApp.getFlightKey(secondAirline, flight, timestamp);
            //console.log(key);
            const flightStruct = await config.flightSuretyData.flights.call(key);
            assert.equal(
              +flightStruct.statusCode, 20,
              'Flight status was not updated correctly'
            );
          });

          it('(passenger) Can withdraw credited insurance amount', async () => {
            let flight = "Athens - Budapest"; // Course number
            let balanceBeforeContract = await web3.eth.getBalance(config.flightSuretyData.address);

            //console.log(balanceBeforeContract)
            let secondAirline = config.airlinesInitial[0];
            let passenger = config.passenger[0];

            const balance = await config.flightSuretyApp.getBalance(passenger);
            //console.log(balance.toString());
            // withdrawal
            const balanceBefore = await web3.eth.getBalance(passenger)
            //console.log(balanceBefore);

            try {
              // let tx = await config.flightSuretyApp.withdraw(secondAirline, flight, timestamp, { from: passenger });
              let tx = await config.flightSuretyApp.withdrawFunds(secondAirline, flight, timestamp, { from: passenger });
              //console.log(tx);
              // truffleAssert.eventEmitted(tx, 'InsurancePaid', ev=>{
              //   return ev.passenger===passenger;
              // });
            } catch (error) {
              console.log(error.message)
            }
            const balanceAfter = await web3.eth.getBalance(passenger);

            //console.log("skata"+balanceAfter);
            let difference = balanceAfter - balanceBefore;
            //console.log("skata");
            //console.log(difference);
            let balanceAfterContract = await web3.eth.getBalance(config.flightSuretyData.address);
            //console.log(balanceAfterContract);


            assert(+difference,payout, "Payout amount is not correct");
          });
  });

  describe(`\n✈️  Multi-Party Consensus ✈️ :`, async() => {

  it(`(multiparty) has correct initial isOperational() value`, async function () {

    // Get operating status
    let status = await config.flightSuretyApp.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");

  });

  it(`(multiparty) can block access to setOperatingStatus() for non-funded airline accounts`, async function () {

      let fifthAirline = config.airlinesVoted[0];
      let accessDenied = false;
      // Ensure that access is denied for non-adequate number of airlines
      let startStatus = await config.flightSuretyApp.isOperational.call();
      let changeStatus = !startStatus;

      try
      {
          await config.flightSuretyApp.setOperatingStatus(changeStatus, {from: fifthAirline});

      }
      catch(e) {
          //console.log(e);
          accessDenied = true;
      }

      assert.equal(accessDenied, true, "Access not restricted to non-funded Airline");

  });


  it(`(multiparty) cannot change operating status for non-adequate number of Airline accounts`, async function () {

      let fifthAirline = config.airlinesVoted[0];

      await config.flightSuretyApp.fundingAirline({ from: fifthAirline, value: expectedRegistrationFee });

      // Ensure that access is denied for non-adequate number of airlines
      let startStatus = await config.flightSuretyApp.isOperational.call();
      let changeStatus = !startStatus;

      try
      {
          await config.flightSuretyData.setOperatingStatus(changeStatus, {from: fifthAirline});

      }
      catch(e) {
        console.log(e);
      }

      let changedStatus = await config.flightSuretyApp.isOperational.call();

      assert.equal(startStatus, changedStatus, "State is changed for non-adequate number of Airlines");

  });

  it(`(multiparty) test whether an Airline can vote a socond time to change the operational status`, async function () {
      let fifthAirline = config.airlinesVoted[0];

      // Ensure that access is denied for non-adequate number of airlines
      let startStatus = await config.flightSuretyApp.isOperational.call();
      let changeStatus = !startStatus;

      try
      {

          //This airline has already voted in the previous test
          await config.flightSuretyData.setOperatingStatus(changeStatus, {from: fifthAirline});

      }
      catch(e) {
        //console.log(e);
      }

      let changedStatus = await config.flightSuretyApp.isOperational.call();

      assert.equal(changedStatus, startStatus, "State isn't changed for an adequate number of Airlines");

  });

  it(`(multiparty) change operating status with adequate number of Airline accounts`, async function () {
      let secondAirline = config.airlinesInitial[0];

      // Ensure that access is denied for non-adequate number of airlines
      let startStatus = await config.flightSuretyApp.isOperational.call();
      let changeStatus = !startStatus;

      try
      {

          //The counter in the mult-party consensus has already register from the previous test, one airline that tries to change state so here is the secondAirline
          //Only  two are required as the whole number of funded airlines is 4
          await config.flightSuretyData.setOperatingStatus(changeStatus, {from: secondAirline});

      }
      catch(e) {
        console.log(e);
      }

      let newStatus = await config.flightSuretyApp.isOperational.call();

      assert.equal(changeStatus, newStatus, "State isn't changed for an adequate number of Airlines");

  });

  it(`(multiparty) block access to functions with requireIsOperational()`, async function () {
      let secondAirline = config.airlinesInitial[0];
      let sixthAirline = config.airlinesVoted[1];

      let accessDenied = false;

      try
      {

          await config.flightSuretyApp.registerAirline("American Airlines", sixthAirline, {from: secondAirline});

      }
      catch(e) {
        //console.log(e);
        accessDenied = true;
      }

      assert.equal(accessDenied, true, "Access to functions isn't block with requireIsOperational() when isn't operational");

  });

});




});
