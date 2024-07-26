// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Lazy.sol";
import "../src/Marketplace.sol";

contract DeployScript is Script {
    function setUp() public {}

    function run() public {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address account = vm.addr(privateKey);

        console.log("Account", account);
        vm.startBroadcast(privateKey);

        Lazy lazyContract = new Lazy();
        address lazyAddress = address(lazyContract);
        
        new MarketPlace();
        vm.stopBroadcast();
    }
}
