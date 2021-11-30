// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/utils/math/SafeMath.sol";
import "../contracts/FlightSuretyData.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)
    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    FlightSuretyData private dataContract;

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    uint8 public INSURANCE_PRICE = 1; // 1 Ether
    uint8 private AIRLINE_REGISTRATION_FEE = 1; //Ether
    uint8 private REQUIRED_VALIDATION_VOTES = 4;



    address private contractOwner;          // Account used to deploy contract

    struct Flight {
        bool valid;
        uint ID;
        uint8 statusCode;
        uint256 updatedTimestamp;
        address airline;
    }
    mapping(uint => Flight) public flights;
    mapping(address => mapping(address => bool)) insurances;
    uint _flightIdCounter = 0;

    struct Votes{
      mapping(address => bool) votes;
      uint count;
    }
    mapping(address => Votes) queedAirlines;                            // after 4 airlines validated this airline, it gets registered

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
           // Modify to call data contract's status
          require(true, "Contract is currently not operational");
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

      modifier requireRegisteredAirline(address _airline){
          require(dataContract.getRegisteredAirline(_airline) == true, "Caller is not a verified airline");
          _;
      }

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor(address payable flightSuretyDataContract) public
    {
      dataContract = FlightSuretyData(flightSuretyDataContract);
      contractOwner = msg.sender;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational() public view returns(bool)
    {
      return dataContract.isOperational();
    }
    function setOperatingStatus(bool status) public requireContractOwner{
      dataContract.setOperatingStatus(status);
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/


   /**
    * @dev Add an airline to the registration queue
    *
    */
    function registerAirline(address airline) payable public requireIsOperational requireRegisteredAirline(msg.sender)
    {
        uint TotalRegisteredAirlines = dataContract.getRegisteredAirlinesCount();
        //
        require(dataContract.getRegisteredAirline(airline) == false, "The Airline has already been registered.");
        require(msg.value >= AIRLINE_REGISTRATION_FEE, "Not enough Ether has been deposited");

        queedAirlines[airline].votes[msg.sender] = true;
        queedAirlines[airline].count += 1;

        if(queedAirlines[airline].count >= REQUIRED_VALIDATION_VOTES){
          dataContract.setRegisteredAirline(airline, true);
        }else if(TotalRegisteredAirlines < 5){
          dataContract.setRegisteredAirline(airline, true);
        }
    }

    function registerAirlineAsOwner(address airline) public requireContractOwner requireIsOperational
    {
      require(dataContract.getRegisteredAirline(airline) == false, "The Airline has already been registered");
      dataContract.setRegisteredAirline(airline, true);
    }

    function voteForAirline(address airline) external requireIsOperational requireRegisteredAirline(msg.sender) returns(uint256)
    {
        Votes storage votes = queedAirlines[airline];
        require(votes.votes[msg.sender] != true, "You already voted for this airline");
        votes.votes[msg.sender] = true;
        votes.count += 1;

        if(votes.count >= REQUIRED_VALIDATION_VOTES){
          dataContract.setRegisteredAirline(airline, true);
        }
        return votes.count;
    }



    function buyInsurance (uint _id) external payable requireIsOperational
    {
         require(flights[_id].statusCode == STATUS_CODE_ON_TIME, "There are already some issues with your airline");
         require(msg.value >= INSURANCE_PRICE, "Insufficient Ethereum has been deposited");

         uint diff = msg.value - INSURANCE_PRICE;
         address payable payableDataContract = payable(address(dataContract));
         if(diff > 0){
           payableDataContract.transfer(INSURANCE_PRICE);
           payable(msg.sender).transfer(diff);
         }else{
           payableDataContract.transfer(INSURANCE_PRICE);
         }
         dataContract.buyInsurance(INSURANCE_PRICE, msg.sender, _id);
    }

    // struct Flight {
    //     bool valid;
    //     uint ID;
    //     uint8 statusCode;
    //     uint256 updatedTimestamp;
    //     address airline;
    // }

    function registerFlight(uint departureTimestamp) public requireIsOperational requireRegisteredAirline(msg.sender) returns(Flight memory)
    {
        require(departureTimestamp > block.timestamp + 3 days, "You can only register your flight at least 3 days before departure");
        require(flights[_flightIdCounter].valid == false, "Internal error, the flightId is already in use");
        flights[_flightIdCounter] = Flight(true, _flightIdCounter, STATUS_CODE_ON_TIME, departureTimestamp, msg.sender);
        _flightIdCounter++;

        return (getFlight(_flightIdCounter-1));
    }

    function getFlight(uint flightId) public view requireIsOperational returns(Flight memory){
      return flights[flightId];
    }

    function getFlightStatus(uint flight_id) external view returns(uint){
        return flights[flight_id].statusCode;
    }

    function processFlightStatus (address airline, uint flightId, uint256 timestamp, uint8 statusCode) internal
    {
        require(flightId > 0, "There is none flight with the provided flightId");
        require(timestamp < block.timestamp, "The timestamp provided by the Oracle is invalid");
        flights[flightId].statusCode = statusCode;
        flights[flightId].updatedTimestamp = timestamp;
    }

    function fetchFlightStatus (address airline,uint flightId,uint256 timestamp) external
    {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flightId, timestamp));
        oracleResponses[key] = ResponseInfo({requester: msg.sender,isOpen: true});

        emit OracleRequest(index, airline, flightId, timestamp);
    }


// region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


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
        //mapping(uint8 => address[]) responses;
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    mapping(bytes32 => mapping(uint8 => address[])) private responsesByType;            // Nested mapping per solc 0.7.0


    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, uint flightId, uint256 timestamp, uint8 status);

    event OracleReport(address airline, uint flightId, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, uint flightId, uint256 timestamp);


    // Register an oracle with the contract
    function registerOracle () external payable requireIsOperational
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({isRegistered: true,indexes: indexes});
    }

    function getMyIndexes () view external returns(uint8[3] memory)
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }




    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse
                        (uint8 index,address airline,uint flight,uint256 timestamp,uint8 statusCode) external
    {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");

        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        responsesByType[key][statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (responsesByType[key][statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(airline, flight, timestamp, statusCode);
            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }


    function getFlightKey(address airline,string memory flight,uint256 timestamp) pure internal returns(bytes32)
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes(address account) internal returns(uint8[3] memory)
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
    function getRandomIndex (address account) internal returns (uint8)
    {
        uint8 maxValue = 10;
        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

// endregion

}

// contract FlightSuretyData {
//   function isOperational() public virtual view returns(bool);
//   function setOperatingStatus() public virtual;
//
//   function setOperatingStatus(bool _status) public virtual;
//   function addAuthorizedCaller(address _address) public virtual;
//   function removeAuthorizedCaller(address _address) public virtual;
//
//   function getRegisteredAirline(address _airline) public view virtual returns (bool);
//   function setRegisteredAirline(address _airline, bool value) public virtual;
//   function getRegisteredAirlinesCount() public view virtual returns (uint);
//
//   function getFlight(uint _id) public view virtual returns (uint id, string memory flight, bytes32 key, address airlineAddress, string memory state, uint departureTimestamp, uint8 departureStatusCode, uint updated);
//
//   function buyInsurance (uint InsuredValue ,address insured , uint flightId) external payable virtual;
// }
