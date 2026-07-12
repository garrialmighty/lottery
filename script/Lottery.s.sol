// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {Lottery} from "../src/Lottery.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

contract LotteryDeploy is Script {
    function run()
        external
        returns (Lottery, HelperConfig.NetworkConfig memory)
    {
        // Declare outside broadcast so as not to spend gas and deploy to the chain.
        HelperConfig config = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = config.getConfig();
        if (networkConfig.subscriptionId == 0) {
            CreateSubscription subscriptionGenerator = new CreateSubscription();
            // Syntactic sugar to auto-assign the return values to the object
            (
                networkConfig.subscriptionId,
                networkConfig.vrfCoordinator
            ) = subscriptionGenerator.createSubscription(
                networkConfig.vrfCoordinator,
                networkConfig.account
            );
            FundSubscription subscriptionFactoryContract = new FundSubscription();
            subscriptionFactoryContract.fundSubscription(
                networkConfig.vrfCoordinator,
                networkConfig.subscriptionId,
                networkConfig.link,
                networkConfig.account
            );
        }
        vm.startBroadcast(networkConfig.account);
        Lottery raffle = new Lottery(
            networkConfig.vrfCoordinator,
            networkConfig.keyHash,
            networkConfig.subscriptionId,
            networkConfig.gasLimit,
            networkConfig.interval
        );
        vm.stopBroadcast();

        // Add consumer here because contract is deployed
        AddConsumer consumerInjector = new AddConsumer();
        consumerInjector.enrollConsumer(
            networkConfig.vrfCoordinator,
            address(raffle),
            networkConfig.subscriptionId,
            networkConfig.account
        );

        // We also return the config so tests can use the `vrfCoordinator`
        return (raffle, networkConfig);
    }
}
