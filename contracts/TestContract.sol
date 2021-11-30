
pragma solidity ^0.8.0;
//SPDX-License-Identifier: MIT

contract TestContract {

mapping(uint => bool) public flightsValid;
uint _flightIdCounter = 0;


  function registerFlight() public returns (bool)
  {
        flightsValid[_flightIdCounter] = true;
        _flightIdCounter++;

      return (flightsValid[_flightIdCounter-1]);
  }

  function getFlight(uint flightId) public view returns(bool){
    return flightsValid[flightId];
  }
}
