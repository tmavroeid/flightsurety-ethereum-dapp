pragma solidity ^0.5.0;


import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;
    //using SafeMath for uint8;
    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false
    mapping (address => bool) private registeredAirlines;
    //mapping (address => uint) private fundedAirlines;
    mapping(address => bool) private authorizedContracts;
    address[] public airlines;

    uint256 public constant REGISTRATION_FUND = 10 ether;
    uint8 public numFundedAirlines;
    mapping(address => bool) private fundedAirlines;


    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 takeoffTimestamp;
        address airline;
        string name;
        string destination;
        uint256 arrival;
        uint ticketprice;
    }
    mapping(bytes32 => Flight) public flights;

//this will track insurance for each passenger
  /*    struct PassengerInsurance {
        address  passenger;
        uint     insuranceamount;
        uint     payout;
    }  */
    //this will track insurance for each airline

    //use Pascal case for sruct
    /* struct Airlineinsurance {
        string cid;
        //string   flight;
        //uint256  timestamp;
        uint     insuranceamount;
        //uint    payout;
    }
    struct Payment{
        uint purchasedamount;
        uint payout;
    } */

    //mapping (bytes32 => Airlineinsurance[]) airlinesInsuranceHistory;
   // mapping (address => passengerInsurance[]) passengerInsuranceHistory;
   //passenger => amount
    mapping(address => uint) public accountBalance;
    //flightkey => passengers
    mapping(address => bool) private passengerinsured;
    mapping(bytes32 =>address[]) private airlineinsurees;
    //mapping(address =>mapping(bytes32 => Payment)) insuredamount;
    //passenger =>(flightkey => amount)
    mapping(address =>mapping(bytes32 => uint)) insuredamount;
    mapping(address => uint) private fundedinsurance;

    //flightkey =>(passenger => payout)
    mapping(bytes32 =>mapping(address => uint)) insuredpayout;

    bool flag = false;

    address[] multiAddress = new address[](0);
    mapping (address => bool) private multiCalls;
    uint8 public counter;
    address private f;

    event ContractAuthorized(address contractAddress);
    event ContractDeauthorized(address contractAddress);
    event InsurancePaid(address passenger);
    //address[] public airlinesInsurances;
     // Max Fee to be paid when buying insurance

    //uint256 public constant MIN_FUNDING_AMOUNT = 10 ether;
    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/


    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    *      firstAirline is registered
    */
    constructor
                                (
                                    address firstAirline
                                )
                                public
    {
        contractOwner = msg.sender;
        registeredAirlines[firstAirline] = true;
        airlines.push(firstAirline);
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational()
    {
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

     modifier requireIsCallerAirlineRegistered(address caller)
    {
        require( registeredAirlines[caller] == true, "Caller not registered");
        _;
    }

     modifier requireisAirlineNotRegistered(address airline)
    {
        require( registeredAirlines[airline] == false, "Airline already registered");
        _;
    }
    modifier requireIsCallerAuthorized()
    {
        require(authorizedContracts[msg.sender] == true, "Caller is not contract owner");
        _;
    }



    modifier requireAirlineFunded(address airline)
    {
        require( fundedAirlines[airline] == true, "Airline must submit funds of 10 ether");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isnotinsured(address airline,string calldata flight,uint timestamp,address passenger)
                    external
                    view
                    returns(bool)
    {
        bytes32 flightkey = getFlightKey(airline,flight,timestamp);
        uint amount = insuredamount[passenger][flightkey];
        return(amount == 0);
    }

    function isAirlineRegistered(address airlineAddress)
                            public
                            view
                            returns (bool)
    {
        return registeredAirlines[airlineAddress];
    }
    /**
    * @dev airline can only take part in registration of other airlines
    *     if it has more than 10 ether in its balance
    */
    function isAirlineFunded(address airlineAddress)
                            public
                            view
                            returns (bool)
    {

        return fundedAirlines[airlineAddress];
    }


    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */
    function isOperational() public view returns(bool){
            return operational;
    }

    function numOfAirlines() public view returns(uint count){
            return airlines.length;
    }

    function numOfFundedAirlines() public view returns(uint8){
      return (numFundedAirlines/2);
    }
    function getCounter() public view returns(uint8){
      return counter;
    }
    function getInsuree(address passenger)public view returns(bool){
      return passengerinsured[passenger];

    }
    function setStatusCodeOnFlight(bytes32 key, uint8 statuscode) external requireIsOperational requireIsCallerAuthorized{
      flights[key].statusCode = statuscode;
    }
        /**
        * @dev Sets contract operations on/off
        *
        * When operational mode is disabled, all write transactions except for this one will fail
        */

    function setOperatingStatus
                              (
                                bool mode
                              )
                              external
                              requireIsCallerAirlineRegistered(msg.sender)
                              requireAirlineFunded(msg.sender)
        {
            require(mode != operational, "New mode must be different from existing mode");

            bool isDuplicate = false;
            if (multiCalls[msg.sender] == true) {
                  isDuplicate = true;
            }

            require(!isDuplicate, "Caller has already called this function.");

            multiAddress.push(msg.sender);
            counter++;
            multiCalls[msg.sender] = true;
            //fundedAirlines = flightSuretyData.numOfFundedAirlines();

            if (counter >= numFundedAirlines/2) {
                operational = mode;
                for(uint i=0;i<multiAddress.length; i++){
                  f = multiAddress[i];
                  delete multiCalls[f];
                }
                multiAddress = new address[](0);
                counter = 0;
            }
        }
    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    //  function authorizeCaller
    //                         (
    //                             address contractAddress
    //                         )
    //                         external
    //                         requireContractOwner
    // {
    //     authorizedContracts[contractAddress] = 1;
    //
    // }
    //
    // function deauthorizeCaller
    //                         (
    //                             address contractAddress
    //                         )
    //                         external
    //                         requireContractOwner
    // {
    //     delete authorizedContracts[contractAddress];
    // }

    function authorizeCallerContract(address callerAddress)
    external
    requireContractOwner
    requireIsOperational
    {
        require(authorizedContracts[callerAddress]==false, "Caller address is already authorized!!");
        authorizedContracts[callerAddress] = true;
        emit ContractAuthorized(callerAddress);
    }

    function deauthorizeCallerContract(address callerAddress)
    external
    requireContractOwner
    requireIsOperational
    {
        require(authorizedContracts[callerAddress]==true, "Caller address is already deauthorized!!");
        delete authorizedContracts[callerAddress];
        emit ContractDeauthorized(callerAddress);
    }
   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */
    function registerAirline
                            (
                                address _airline
                            )
                            external
                            requireIsOperational
                            requireIsCallerAuthorized
                            returns(bool successfulRegistration)
    {
        registeredAirlines[_airline] = true;
        successfulRegistration = true;
        airlines.push(_airline);
        return successfulRegistration;
    }


    function registerFlight
                                (
                                    address _airline,
                                    string calldata _flightName,
                                    uint256 _takeoffTimestamp,
                                    string calldata _destination,
                                    uint256 _arrival,
                                    uint _ticketprice
                                )
                                external
                                requireIsOperational
                                requireIsCallerAuthorized
                                returns(bytes32)
    {
        bytes32 _flightkey = getFlightKey(_airline,_flightName,_takeoffTimestamp);
        flights[_flightkey] = Flight({isRegistered: true, statusCode: 0, takeoffTimestamp: _takeoffTimestamp, airline: _airline, name: _flightName, destination: _destination, arrival: _arrival, ticketprice: _ticketprice});
        return _flightkey;
    }

    function getAirlines()
                external
                view
                returns(address[] memory)


    {
        return airlines;
    }


    function getPassengerFunds(address passenger)
                external
                view
                returns(uint)


    {

        return accountBalance[passenger];
    }
    // function getInsurees(address _airline,string calldata _flightName,uint256 _takeoffTimestamp, address passenger)
    //             external
    //             view
    //             returns(uint)
    //
    //
    // {
    //
    //   bytes32 flightkey = getFlightKey(_airline,_flightName,_takeoffTimestamp);
    //
    //   return insuredamount[passenger][flightkey];
    // }
    function withdrawPassengerFunds(address _airline,string calldata _flightName,uint256 _takeoffTimestamp,address payable passenger)
                                    external
                                    requireIsOperational
                                    requireIsCallerAuthorized
                                    returns(uint)
    {
        bytes32 flightkey = getFlightKey(_airline,_flightName,_takeoffTimestamp);
        uint amount = insuredamount[passenger][flightkey];
        // //accountBalance[passenger] = accountBalance[passenger] - amount;
        // passenger.transfer(accountBalance[passenger]);
        // emit InsurancePaid(passenger);
        // return accountBalance[passenger];
        accountBalance[passenger] = accountBalance[passenger] - amount;
        passenger.transfer(amount);

        return accountBalance[passenger];
    }

/**
  * @dev airline can deposit funds in any amount
 */
     function fund(address _airlineAddress) public
                             payable
                             requireIsOperational
                             requireIsCallerAuthorized
     {
         fundedAirlines[_airlineAddress] = true;
         numFundedAirlines++;
         //return true;
     }


    /**
  * @dev to see how much fund an airline has
 */
    function getAirlineFunds
                            (
                                address airline

                            )
                            external
                            view
                            requireIsOperational
                            requireIsCallerAuthorized
                            requireIsCallerAirlineRegistered(airline)
                            returns(bool)

    {
        return (fundedAirlines[airline]);
    }

   /**
    * @dev Buy insurance for a flight. If a passenger sends more than 1 ether then the excess is returned.
    *
    */

     function buy (address _airline,string calldata _flightName,uint256 _takeoffTimestamp, address _passenger,uint _amount)
                            external
                            payable
                            requireIsOperational
                            requireIsCallerAuthorized
    {

        bytes32 _flightkey = getFlightKey(_airline,_flightName,_takeoffTimestamp);
        require(!passengerinsured[_passenger], "The passenger has already taken insurance");
       // PassengerInsurance memory pinsurance = PassengerInsurance({passenger:_passenger,insuranceamount:amount,payout:0});
        //airlineInsurance[flightkey].push(pinsurance);
        passengerinsured[_passenger]=true;
        airlineinsurees[_flightkey].push(_passenger);

        insuredamount[_passenger][_flightkey]= _amount;
        insuredpayout[_flightkey][_passenger] = 0;


    }
    uint public  total = 0;
    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
                                (
                                    address _airline,
                                    string calldata _flightName,
                                    uint256 _takeoffTimestamp,
                                    uint factor_numerator,
                                    uint factor_denominator

                                )
                                external
                                requireIsOperational
                                requireIsCallerAuthorized

    {
          //get all the insurees
          bytes32 flightkey = getFlightKey(_airline,_flightName,_takeoffTimestamp);

          address[] storage insurees = airlineinsurees[flightkey];


          for(uint8 i = 0; i < insurees.length; i++) {
               address passenger = insurees[i];
               uint256 payout;
               uint amount = insuredamount[passenger][flightkey];

               //check if already paid
               uint paid = insuredpayout[flightkey][passenger];
               if(paid == 0){
                 // bool success = _appcontract.call(bytes4(keccak256("calculatePayout(uint256)")), amount);
                    payout = amount.mul(factor_numerator).div(factor_denominator);

                    insuredpayout[flightkey][passenger] = payout;
                    accountBalance[passenger] = accountBalance[passenger] + payout;

              }

          }
    }

    function getPayout( address _airline, string memory _flightName, uint256 _takeoffTimestamp, address passenger) public
    view
    returns(uint)
    {
      bytes32 flightkey = getFlightKey(_airline,_flightName,_takeoffTimestamp);
      uint payout = insuredpayout[flightkey][passenger];
      return payout;

    }


    //functions to debug contract
    /*  function getInsurees(address airline,string flight,uint ts)
                        external
                         view
                         requireIsOperational
                        requireIsCallerAuthorized
                        returns(PassengerInsurance[])
        {

       // PassengerInsurance memory pinsurance
             bytes32 flightkey = getFlightKey(airline,flight,ts);
            PassengerInsurance[] storage insurees = airlineInsurance[flightkey];//airlineinsurees[flightkey];

            return insurees;
        } */
/*
         function isAmountNotPaid(address airline,string flight,uint ts,address passenger)
                        external
                         view
                         requireIsOperational
                        requireIsCallerAuthorized
                        returns(bool)
        {

            bytes32 flightkey = getFlightKey(airline,flight,ts);
            uint paid = insuredpayout[flightkey][passenger];
            return (paid == 0);
        } */

        function getAccountBalance(address passenger)
                                    internal
                                    view
                                    requireIsOperational
                                    requireIsCallerAuthorized
                                    returns(uint)
             {
                return accountBalance[passenger];
             }

       /*  function getInsuredAmount(address airline,string flight,uint ts,address passenger)
                        external
                         view
                         requireIsOperational
                        requireIsCallerAuthorized
                        returns(uint)
        {

            bytes32 flightkey = getFlightKey(airline,flight,ts);
            uint amount = insuredamount[passenger][flightkey];
            return amount;
        } */

    /* function getInsureesAmount(address airline,string flight,uint ts) external  returns(uint)
    {

        bytes32 flightkey = getFlightKey(airline,flight,ts);
        address[] storage insurees = airlineinsurees[flightkey];
          for(uint8 i = 0; i < insurees.length; i++) {
                address passenger = insurees[i];

                total = total + accountBalance[passenger];
          }
          return total;


    } */
    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay
                            (   address _airline,
                                string calldata _flightName,
                                uint256 _takeoffTimestamp,
                                address payable passenger
                            )
                            external
                            requireIsOperational
                            requireIsCallerAuthorized

    {
        bytes32 flightkey = getFlightKey(_airline,_flightName,_takeoffTimestamp);
        //uint balance = getAccountBalance(passenger);
        insuredpayout[flightkey][passenger] = 0;
        accountBalance[passenger] = 0;
        //insuredpayout[flightkey][passenger] = payout;
        //accountBalance[passenger] += payout;

        //uint256 prev = accountBalance[customerAddress];
        //accountBalance[customerAddress] = 0;
        //passenger.transfer(balance);

    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */

    function getFlightKey
                        (
                            address airline,
                            string memory flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32)
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    function getFlightStatusCode(bytes32 key) external view returns(uint8){
      return flights[key].statusCode;
    }
    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function()
                            external
                            payable
                            requireIsCallerAuthorized
    {
       require(msg.data.length == 0);
       this.fund(msg.sender);
    }


}
