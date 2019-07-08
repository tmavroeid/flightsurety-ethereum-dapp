pragma solidity ^0.5.0;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)
    using SafeMath for uint8;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Flight status codes
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;
    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;
    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;
    uint8 private constant MIN_AIRLINES_FOR_MULTIPARTY_REGISTRATION = 4;
    uint256 public constant MAX_INSURANCE_FEE = 1 ether;
    uint256 public constant MIN_FUNDING_AMOUNT = 10 ether;

    address private contractOwner;          // Account used to deploy contract
    uint8 public numOfRegisteredAirlines;
    uint8 public fundedAirlines;


    bool private operational = true;       // Blocks all state changes throughout the contract if false

    struct Airline {
        string name;
        RegistrationState state;
        bool funded;
        uint8 numOfVotes;
    }
    mapping(address => Airline) public airlines;
    mapping(address => bool) public exist;

    enum RegistrationState {
        WaitingToBeVoted,
        Registered
    }
    address[] addedAirlines;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) public oracleResponses;



   //it contains the list of airline addresses which are voting for another airline
   //<<airlinebeingregistered> => (<callingairline> => bool)
    mapping(address => mapping(address => bool)) private airlinePolls;
   // mapping(address => address[]) private airlinePolls;

    //no of airlines voted for the airline to be registered
    mapping(address => uint8) private noOfVoters;

    address payable flightContractData;

    FlightSuretyData flightSuretyData;

    // Flight data persisted forever
    struct FlightStatus {
        bool hasStatus;
        uint8 status;
    }

    mapping(bytes32 => FlightStatus) flights;

    event FlightRegistered(bytes32 flightkey);
    event PassengerInsured(address passenger);

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status, bool verified);

    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);
    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp, bool isOpen, bytes32 key);
    event FlightProcessed(string flight, uint256 timestamp, uint8 statusCode);
    event WithdrawRequest(address recipient);

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
         //  call data contract's status
        require(flightSuretyData.isOperational(), "Contract is currently not operational");
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

    modifier requireCallerAirlineRegistered()
    {

        require(flightSuretyData.isAirlineRegistered(msg.sender), "Airline not registered");
        _;
    }

    modifier requireAirlineNotRegisteredYet(address airline)
    {
        require(!flightSuretyData.isAirlineRegistered(airline), "Airline already registered");
        _;

    }
     modifier requireIsAirlineRegistered(address airline)
    {
        require(flightSuretyData.isAirlineRegistered(airline), "Airline not registered");
        _;

    }
    modifier requireIsAirlineFunded(address airline){
      require(flightSuretyData.isAirlineFunded(airline), "Airline not registered");
      _;
    }

    modifier requireCallerAirlineFunded()
    {
        bool funded = flightSuretyData.getAirlineFunds(msg.sender);

        require(funded == true, "Airline can not participate in contract until it submits 10 ether");
        _;
    }

    modifier requireIsTimestampValid(uint timestamp)
    {
       uint currentTime = block.timestamp;
       require(timestamp >= currentTime,"Timestamp is not valid");
        _;
    }


    modifier requireDidNotpurchaseInsurance(address airline,string memory flight,uint timestamp)
    {
        require(flightSuretyData.isnotinsured(airline,flight,timestamp,msg.sender),"You are already insured");
        _;
    }
    // Part of app contract (business rule that might change)
    modifier adequateFunding() {
        require(msg.value >= MIN_FUNDING_AMOUNT, "Minimun funding amount is 10 ETH");
        _;
    }

    /* do not process a flight more than once,
        which could e.g result in the passengers being credited their insurance amount twice.
        */
    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor
                                (
                                     address dataContract, string memory _name, address firstAirline
                                )
                                public
    {
        contractOwner = msg.sender;
        flightSuretyData = FlightSuretyData(dataContract);
        flightContractData = address(uint160(dataContract));
        airlines[firstAirline] = Airline({name: _name, state: RegistrationState.Registered, funded: false, numOfVotes: 0});
        numOfRegisteredAirlines++;
        addedAirlines.push(firstAirline);


    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational()
                            public
                            view
                            returns(bool)
    {
        return flightSuretyData.isOperational();  // Modify to call data contract's status
    }

    // function votes(address _airline) public view returns(uint){
    //   return airlines[_airline].numOfVotes;
    // }
    function numRegistered() public view returns(uint8){
      return numOfRegisteredAirlines;
    }

    function getfunded()public view returns(uint8){
      return flightSuretyData.numOfFundedAirlines();
    }


    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/


   /**
    * @dev Add an airline to the registration queue. If there are more than 4 registered airlines
    *      then there needs to be a consensus of 50% of the registered airlines
    *
    */
    function registerAirline
                            (
                                string calldata _name,
                                address _airline
                            )
                            external
                            requireIsOperational
                            requireCallerAirlineRegistered
                            requireCallerAirlineFunded
                            requireAirlineNotRegisteredYet(_airline)
                            returns(bool successfulRegistration, uint256 votes)
    {
        require(_airline != address(0), "Airline must be a valid address.");

        successfulRegistration = false;
        votes = 0;
        if(numOfRegisteredAirlines < MIN_AIRLINES_FOR_MULTIPARTY_REGISTRATION) {

            airlines[_airline] = Airline({name: _name, state: RegistrationState.Registered, funded: false, numOfVotes: 0});
            exist[_airline] = true;
            successfulRegistration = flightSuretyData.registerAirline(_airline);
            if(successfulRegistration) {
                numOfRegisteredAirlines ++;
            }
        }else{
            if(!exist[_airline]){
              airlines[_airline] = Airline({name: _name, state: RegistrationState.WaitingToBeVoted, funded: false, numOfVotes: 0});
              exist[_airline] = true;
            }

            mapping(address=>bool) storage supportingAirlines = airlinePolls[_airline];
            //check if the airline is not calling 2nd time
            if(!supportingAirlines[msg.sender]){
                airlinePolls[_airline][msg.sender] = true; //add the sender to the list of voters for the airline
                //noOfVoters[airline] ++;
                airlines[_airline].numOfVotes ++;
                if(airlines[_airline].numOfVotes >= numOfRegisteredAirlines.div(2))
                {
                    successfulRegistration = flightSuretyData.registerAirline(_airline);
                    votes = airlines[_airline].numOfVotes;
                    airlines[_airline].state = RegistrationState.Registered;
                    exist[_airline] = true;
                    if(successfulRegistration) {
                      numOfRegisteredAirlines++;
                    }
                }
             }

            }

        return (successfulRegistration, votes);
    }
     /**
    * @dev add funds for airline.
    *
    */
    function fundingAirline()
    public
    payable
    requireIsOperational
    adequateFunding
    requireIsAirlineRegistered(msg.sender)
    returns(bool)
    {
        // Transfer Fund to Data Contract
        //address(flightContractData).transfer(msg.value);
        //flightSuretyData.fund(msg.sender,msg.value);
        return flightSuretyData.fund.value(msg.value)(msg.sender);

    }


   /**
    * @dev Register a future flight for insuring.Timestamp is the departure time of a flight.
    *       Purchase Flight insurance before flight departure
    */
    function registerFlight
                                (
                                    address airline,
                                    string memory flightName,
                                    uint256 takeoffTimestamp,
                                    string memory destination,
                                    uint256 arrival,
                                    uint ticketprice
                                )
                                public
                                requireIsOperational
                                requireCallerAirlineFunded
                                requireIsTimestampValid(takeoffTimestamp)
                                requireIsTimestampValid(arrival)

    {
        require(msg.sender==airline, "Caller should be the company owning the flight");
        require(arrival>takeoffTimestamp, "Arrival time should be greater than the takeoff time");
        bytes32 flightkey = flightSuretyData.registerFlight(airline, flightName, takeoffTimestamp, destination, arrival, ticketprice);

        emit FlightRegistered(flightkey);

    }

    function purchaseFlightInsurance
                                (
                                    address airline,
                                    string memory flightName,
                                    uint256 takeoffTimestamp
                                )
                                public
                                payable
                                requireIsOperational
                                requireIsAirlineFunded(airline)
                                requireIsTimestampValid(takeoffTimestamp)
                                //requireDidNotpurchaseInsurance(airline,flightName,timestamp

    {
        require(msg.value <= MAX_INSURANCE_FEE, "Insurance fee must be less than 1 ether");

        flightSuretyData.buy.value(msg.value)(airline, flightName, takeoffTimestamp, msg.sender, msg.value);

        emit PassengerInsured(msg.sender);


        //check if the passenger already has insurance
        //address(flightContractData).transfer(msg.value);

        //flightSuretyData.buy(airline, flightName, arrival, msg.sender, msg.value);
    }

    // function getAmount(address airline, string memory flightName, uint256 takeoffTimestamp) public view returns(uint){
    //   uint result = flightSuretyData.getInsurees(airline, flightName, takeoffTimestamp, msg.sender);
    //   return result;
    // }
   /**
    * @dev Called after oracle has updated flight status
    *
    */
    function processFlightStatus
                                (
                                    address airline,
                                    string memory flightName,
                                    uint256 takeoffTimestamp,
                                    uint8 statusCode
                                )
                                internal
                                requireIsOperational

    {
       // address[] memory insurees = _flightSuretyData.getInsurees(airline, flight, timestamp);
       // generate flightKey
       //bytes32 flightKey = getFlightKey(airline, flightName, takeoffTimestamp);
       //uint8 code = flightSuretyData.getFlightStatusCode(flightKey);
       //require(code == 0, "This flight has already been processed");
       flightSuretyData.creditInsurees(airline, flightName, takeoffTimestamp, 15, 10);
       emit FlightProcessed(flightName, takeoffTimestamp, statusCode);
    }

    // Register an oracle with the contract
    function registerOracle
                            (
                            )
                            external
                            payable
                            requireIsOperational
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
                                        isRegistered: true,
                                        indexes: indexes
                                    });
    }

    function getOracle
                      (
                          address account
                      )
                      external
                      view
                      requireContractOwner
                      returns(uint8[3] memory)
    {
      return oracles[account].indexes;
    }
    /*  function getBalancetest() public view returns(uint)
    {
      return balance;
    } */
    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus
                        (
                            address airline,
                            string calldata flightName,
                            uint256 takeoffTimestamp
                        )
                        external
                        requireIsOperational
                        requireIsAirlineRegistered(airline)

    {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flightName, takeoffTimestamp));
        oracleResponses[key] = ResponseInfo({
                                                requester: msg.sender,
                                                isOpen: true
                                            });

        emit OracleRequest(index, airline, flightName, takeoffTimestamp, oracleResponses[key].isOpen, key);
    }

    // function fetchFlight
    //               (
    //                   address airline,
    //                   string calldata flightName,
    //                   uint256 takeoffTimestamp
    //               )
    //               external
    //               requireIsOperational
    //               requireIsAirlineRegistered(airline)
    //               returns(bytes32)
    //   {
    //     bytes32 flightKey = getFlightKey(airline, flightName, takeoffTimestamp);
    //     //flightSuretyData.setStatusCodeOnFlight(flightKey, statusCode);
    //     return flightKey;
    //   }
    function getMyIndexes
                            (
                            )
                            view
                            external
                            requireIsOperational
                            returns(uint8[3] memory)
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }




    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    // event isKey(bytes32 key);
    //
    //
    //
    // function getKey
    //                     (
    //                         uint8 index,
    //                         address airline,
    //                         string calldata flightName,
    //                         uint256 takeoffTimestamp
    //                     )
    //                     external
    //                     requireIsOperational
    //
    // {
    //   bytes32 key = keccak256(abi.encodePacked(index, airline, flightName, takeoffTimestamp));
    //
    //   emit isKey(key);
    // }


    function submitOracleResponse
                        (
                            uint8 index,
                            address airline,
                            string calldata flightName,
                            uint256 takeoffTimestamp,
                            uint8 statusCode
                        )
                        external
                        requireIsOperational

    {

        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");


        bytes32 key = keccak256(abi.encodePacked(index, airline, flightName, takeoffTimestamp));

        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request. Or request is closed (enough responses received)");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flightName, takeoffTimestamp, statusCode);

        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

                oracleResponses[key].isOpen = false;

            emit FlightStatusInfo(airline, flightName, takeoffTimestamp, statusCode, true);

            // Handle flight status as appropriate
            if(statusCode>=20){
              processFlightStatus(airline, flightName, takeoffTimestamp, statusCode);
              bytes32 flightKey = getFlightKey(airline, flightName, takeoffTimestamp);
              flightSuretyData.setStatusCodeOnFlight(flightKey, statusCode);
            }
        }else{
          emit FlightStatusInfo(airline, flightName, takeoffTimestamp, statusCode, false);

        }

    }

    // function getIsOpen
    //           (
    //               uint8 index,
    //               address airline,
    //               string calldata flightName,
    //               uint256 takeoffTimestamp
    //           )
    //           external
    //           view
    //           returns(bool)
    //           {
    //
    //           bytes32 key = keccak256(abi.encodePacked(index, airline, flightName, takeoffTimestamp));
    //
    //           return oracleResponses[key].isOpen;
    //         }
    function getFlightKey
                        (
                            address airline,
                            string memory flightName,
                            uint256 takeoffTimestamp
                        )
                        pure
                        public
                        returns(bytes32)
    {
        return keccak256(abi.encodePacked(airline, flightName, takeoffTimestamp));
    }

    function getFlightKeyWithIndex
                        (
                            uint8 index,
                            address airline,
                            string memory flightName,
                            uint256 takeoffTimestamp
                        )
                        pure
                        public
                        returns(bytes32)
    {
        return keccak256(abi.encodePacked(index, airline, flightName, takeoffTimestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes
                            (
                                address account
                            )
                            internal
                            returns(uint8[3] memory)
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);

        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex
                            (
                                address account
                            )
                            internal
                            returns (uint8)
    {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

    function getExistingAirlines
                            (

                            )
                             public
                             view
                             requireIsOperational
                             returns(address[] memory)
      {
         return flightSuretyData.getAirlines();
      }

    function getAirlinesFunded
                            (
                            )
                            public
                            view
                            requireIsOperational
                            returns(address[] memory)
      {
        return flightSuretyData.getFundedAirlines();
      }

        // function getAirlineFunds
        //                     (
        //                     address airline
        //                     )
        //                      public
        //                      view
        //                      requireIsOperational
        //                      returns(bool)
        // {
        //  return flightSuretyData.getAirlineFunds(airline);
        // }

        function getBalance
                            (
                              address passenger
                            )
                            public
                            view
                            requireIsOperational
                            returns(uint)
            {
                return flightSuretyData.getPassengerFunds(passenger);

            }


            // function withdraw(address _airline,string calldata _flightName, uint256 _takeoffTimestamp) external requireIsOperational
            // {
            //     flightSuretyData.pay(_airline, _flightName, _takeoffTimestamp, msg.sender);
            //     emit WithdrawRequest(msg.sender);
            // }

            function withdrawFunds
            (
                address airline,
                string memory flightName,
                uint256 takeoffTimestamp
            )
            public
            requireIsOperational
            returns(uint)
            {
                //uint balance = flightSuretyData.getPassengerFunds(msg.sender);

                //require(amount <= balance, "Requested amount exceeds balance");

                uint funds = flightSuretyData.withdrawPassengerFunds(airline, flightName, takeoffTimestamp ,msg.sender);
                return funds;
            }


           /*  function getInsured(address airline, string flight, uint ts) public view returns(address[] insurees)
            {
                return _flightSuretyData.getInsurees(airline,flight,ts);
            }
            function getInsuredamount(address airline, string flight, uint ts) public view returns(uint amount)
            {
                return _flightSuretyData.getInsureesAmount(airline,flight,ts);
            } */

// endregion

}

contract FlightSuretyData {
    //address [] public insurees;
    function setStatusCodeOnFlight(bytes32 key, uint8 statuscode) external;
    function isOperational() public view returns(bool);
    function isFlightRegistered(bytes32 identifier) public view returns(bool);
    function numOfFundedAirlines() public view returns(uint8);
    function isAirlineRegistered(address airline) public view returns (bool);
    function isAirlineFunded(address airline) public view returns (bool);
    function registerAirline(address airline) external returns (bool success);
    function registerFlight(address _airline, string calldata _flightName, uint256 _takeoffTimestamp, string calldata destination, uint256 arrival, uint ticketprice) external returns(bytes32);
    function getFlightStatusCode(bytes32 key) external view returns(uint8);
    function fund(address airline) public payable returns(bool);
    function buy(address airline, string calldata flight, uint256 timestamp,address passenger, uint256 amount) external payable;
    function creditInsurees(address airline, string calldata flightName, uint256 timestamp,uint factor_numerator,uint factor_denominator) external;
    function getAirlines() external view returns(address[] memory);
    function getFundedAirlines() external view returns (address[] memory);
    function getAirlineFunds(address airline) external view returns(bool);
    function isnotinsured(address airline,string calldata flight,uint timestamp,address passenger) external view returns(bool);
    function getPassengerFunds(address passenger) external view returns(uint);
    function withdrawPassengerFunds(address _airline,string calldata _flightName,uint256 _takeoffTimestamp,address passenger) external returns(uint);
    function pay(address _airline,string calldata _flightName,uint256 _takeoffTimestamp, address payable passenger) external;
    function getInsurees(address _airline,string calldata _flightName,uint256 _takeoffTimestamp, address passenger) external view returns(uint);
    // function getInsurees(address airline,string flight,uint ts)  external view returns(address[]);
    /* function isAmountNotPaid(address airline,string flight,uint ts,address passenger) external view returns(bool);
    function getInsuredAmount(address airline,string flight,uint ts,address passenger) external view returns(uint);
    function pay(address airline,string flight,uint ts,address passenger,uint payout) external; */

    /* function getInsurees(address airline,string flight,uint ts) external view returns(address[]);
    function getInsureesAmount(address airline,string flight,uint ts) external view returns(uint);  */

}
