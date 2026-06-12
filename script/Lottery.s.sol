// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {Lottery} from "../src/Lottery.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract LotteryDeploy is Script {
    function run() external returns (Lottery) {
        // Declare outside broadcast so as not to spend gas and deploy to the chain.
        HelperConfig config = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = config.getConfig();

        vm.startBroadcast();
        Lottery raffle = new Lottery(
            networkConfig.vrfCoordinator,
            networkConfig.keyHash,
            networkConfig.subscriptionId,
            networkConfig.gasLimit,
            networkConfig.interval
        );
        vm.stopBroadcast();
        return raffle;
    }
}
