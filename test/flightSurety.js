
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests', async (accounts) => {

  var config;
  before('setup contract', async () => {
    config = await Test.Config(accounts);
    await config.flightSuretyData.addAuthorizedCaller(config.flightSuretyApp.address);
  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  it(`(multiparty) has correct initial isOperational() value`, async function () {

    // Get operating status
    let status = await config.flightSuretyData.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");

  });

  it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

      // Ensure that access is denied for non-Contract Owner account
      let accessDenied = false;
      try
      {
          await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] });
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, true, "Access not restricted to Contract Owner");

  });

  it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

      // Ensure that access is allowed for Contract Owner account
      let accessDenied = false;
      try
      {
          await config.flightSuretyData.setOperatingStatus(false);
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, false, "Access not restricted to Contract Owner");

  });

  it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

      await config.flightSuretyData.setOperatingStatus(false);

      let reverted = false;
      try
      {
          await config.flightSurety.setTestingMode(true);
      }
      catch(e) {
          reverted = true;
      }
      assert.equal(reverted, true, "Access not blocked for requireIsOperational");

      // Set it back for other tests to work
      await config.flightSuretyData.setOperatingStatus(true);

  });

  it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {

    // ARRANGE
    let newAirline = accounts[2];

    // ACT
    try {
        await config.flightSuretyApp.registerAirline.send(newAirline, {from: config.firstAirline});
    }
    catch(e) {

    }
    let result = await config.flightSuretyData.getRegisteredAirline.call(newAirline);

    // ASSERT
    assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");

  });

  it('(Owner) can register an Airline using registerAirlineAsOwner()', async () => {

    // ARRANGE
    let newAirline = config.firstAirline;
    // ACT
    try {
        await config.flightSuretyApp.registerAirlineAsOwner(newAirline, {from: config.owner});
    }
    catch(e) {

    }
    let result = await config.flightSuretyData.getRegisteredAirline.call(newAirline);
    // ASSERT
    assert.equal(result, true, "Owner should be able to register another airline");

  });

  it('(Airline) can register an Airline using registerAirline() if it provided the necessary funding', async () => {
    // ARRANGE
    let registeredAirline = config.firstAirline;
    let registrationAirlineFee = web3.utils.toWei("2", "ether");

    let newAirline = accounts[3];
    // ACT
    try {
      await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline, value: registrationAirlineFee});
    }
    catch(e) {
      console.log(e);
    }
    let result = await config.flightSuretyData.getRegisteredAirline.call(newAirline);
    // ASSERT
    assert.equal(result, true, "Airline should be able to register another airline if it has provided funding");
  });

  it('(Airline) can register an Flight using registerFlight()', async () => {

    // ARRANGE
    let registeredAirline = accounts[2];
    await config.flightSuretyData.getRegisteredAirline.call(registeredAirline);
    let flightId = -1;
    // ACT
    try {
      // flightId = await config.flightSuretyApp.registerFlight.call(Date.now() + 7 * 24 * 60 * 60 * 1000, {from: config.firstAirline});
      let result = await config.flightSuretyApp.registerFlight.call(Date.now() + 7 * 24 * 60 * 60 * 1000, {from: config.firstAirline});
      result.map((v, i) => {
        console.log(v.valueOf());
      })
      console.log(await config.flightSuretyApp.getFlight.call(0));
      console.log(await config.flightSuretyApp.getFlight.call(1));
      console.log(await config.flightSuretyApp.getFlight.call(2));
    }
    catch(e) {
      console.log(e);
    }
    // ASSERT
    assert.equal(flightId, 1, "New Flight should be registered with the ID: 1");
  });

  it('(Someone) can fetch the status of a flight using getFlight()', async () => {

    // ARRANGE
    let flightId;
    let airline;
    // ACT
    try {
      // flightId = await config.flightSuretyApp.registerFlight.call(Date.now() + 7 * 24 * 60 * 60 * 1000, {from: config.firstAirline});
      // console.log("FlightId: " + flightId);
      // airline = await config.flightSuretyApp.getFlight.call(flightId).airline;
      // console.log("airline: " + airline);
      // console.log(await config.flightSuretyApp.getFlight.call(0));
      // console.log(await config.flightSuretyApp.getFlight.call(1));
      // console.log(await config.flightSuretyApp.getFlight.call(2));
      // console.log(await config.flightSuretyApp.getFlight.call(3));

    }
    catch(e) {
      // console.log(e);
    }
    // ASSERT
    assert.equal(airline, config.firstAirline, `fetched airline with the id ${flightId} should match with the address of the provided address`);
  });

});
