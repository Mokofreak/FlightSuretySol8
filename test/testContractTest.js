
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');
var TestContract = artifacts.require("TestContract");

contract('TestContract Tests', async (accounts) => {

  var testContract
  var config;
  before('setup contract', async () => {
    config = await Test.Config(accounts);
    testContract = await TestContract.new();
  });

  it(`Struct is able to save values`, async function () {
    let val1;
    let val2;
    try{
      val1 = await testContract.registerFlight.call();
      console.log(val1);
      val2 = await testContract.getFlight.call(0);
      console.log(val2);

      console.log(await testContract.getFlight.call(1));
      console.log(await testContract.getFlight.call(2));

    }catch(e){
      console.log(e);
    }

    assert.equal(val1, val2, "Couldn't get the right value");

  });
});
