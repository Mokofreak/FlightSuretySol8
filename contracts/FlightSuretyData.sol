// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../node_modules/openzeppelin-solidity/contracts/utils/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false
    mapping(address => bool) private isAirline;                         // Blocks all state changes throughout the contract if false
    mapping (address => bool) authorizedCallers;
    uint registeredAirlinesCount = 0;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/


    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor () public
    {
        contractOwner = msg.sender;
        authorizedCallers[msg.sender] = true;
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

    modifier requireRegisteredAirline(address _airline){
        require(isAirline[_airline], "Caller is not a verified airline");
        _;
    }

    modifier requireAuthorizedCaller(){
        require(authorizedCallers[msg.sender] == true, "The caller is not authorized");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */
    function isOperational() public view returns(bool)
    {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */
    function setOperatingStatus (bool mode) external requireContractOwner
    {
        operational = mode;
    }

    function addAuthorizedCaller (address appAddress) external requireContractOwner
    {
        authorizedCallers[appAddress] = true;
    }

    function removeAuthorizedCaller (address appAddress) external requireContractOwner
    {
        authorizedCallers[appAddress] = false;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    /*****************************************************************/
    /*                       Register Airline                        */
    /*****************************************************************/

    event registerAirlineEvent(address airlineAddress,bool registered, uint TotalRegisteredAirlines);

    function getRegisteredAirline(address _airline) external view requireIsOperational returns(bool)
    {
      return isAirline[_airline];
    }

    function setRegisteredAirline(address _airline, bool value) external requireIsOperational requireAuthorizedCaller
    {
      if(isAirline[_airline] != value){
        if(value == true){
          registeredAirlinesCount++;
          emit registerAirlineEvent(_airline, true, registeredAirlinesCount);
        }else{
          registeredAirlinesCount--;
        }
        isAirline[_airline] = value;
      }
    }

    function getRegisteredAirlinesCount() external view requireIsOperational returns (uint) {
      return registeredAirlinesCount;
    }


    /****************************************************************/
    /*                         Insurance                            */
    /****************************************************************/


    struct InsuranceStruct{
        uint value;
        address flightId;
        uint256 bought;
        uint256 finished;
    }

    struct InsurancesStruct{
      uint TotalValue;
      mapping(address => mapping(uint => uint)) Insurances;   /*Insurees address -> flightID -> Insured Amount*/
    }
    InsurancesStruct private AllInsurances;

    function buyInsurance (uint InsuredValue ,address insured , uint flightId) external payable requireIsOperational requireAuthorizedCaller returns(bool)
    {
      require(msg.value >= InsuredValue ,"Not enough ether had been send");
      AllInsurances.TotalValue += InsuredValue;
      AllInsurances.Insurances[insured][flightId] = InsuredValue;

      return true;
    }
    function getInsuranceValue (address insured , uint flightId) external view requireIsOperational requireAuthorizedCaller returns(uint)
    {
      return AllInsurances.Insurances[insured][flightId];
    }
    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsured (address payable insured, uint flightId) external requireIsOperational requireAuthorizedCaller returns (bool)
    {
      uint payoutValue = AllInsurances.Insurances[insured][flightId];
      require(address(this).balance >= payoutValue, "Data Contract has not enough Ether");

      AllInsurances.Insurances[insured][flightId] = 0;
      AllInsurances.TotalValue -= payoutValue;
      insured.transfer(payoutValue);

      return true;
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */
    function fund () public payable requireIsOperational returns (bool)
    {

    }

    function getFlightKey (address airline,string memory flight,uint256 timestamp) requireIsOperational view internal returns(bytes32)
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    fallback() external payable
    {
        fund();
    }

    /**
    * @dev Receive function for funding smart contract
    *
    */
    receive() external payable
    {
        fund();
    }

}
