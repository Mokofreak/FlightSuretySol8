var HDWalletProvider = require("@truffle/hdwallet-provider");
// var mnemonic = "candy maple cake sugar pudding cream honey rich smooth crumble sweet treat";
var mnemonic = "hawk laugh hunt crawl balance guard tell daughter begin curtain author dentist";

module.exports = {
  networks: {
    development: {
      provider: function() {
        return new HDWalletProvider(mnemonic, "http://127.0.0.1:8545/", 0, 50);
      },
      network_id: '*',
      gas: 4700000
    }
  },
  compilers: {
    solc: {
      version: "^0.8.0"
    }
  }
};
