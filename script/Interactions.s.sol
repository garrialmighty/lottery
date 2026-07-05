// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {HelperConfig, Constants} from "./HelperConfig.s.sol";
import {LinkToken} from "../test/mock/LinkToken.sol";

contract CreateSubscription is Script {
    function generateSubscription() internal returns (uint256, address) {
        HelperConfig config = new HelperConfig();

        // Apparently accessing the property directly will not return the object
        address vrfCoordinator = config.getConfig().vrfCoordinator;
        (uint256 subId, ) = createSubscription(vrfCoordinator);
        return (subId, vrfCoordinator);
    }

    function createSubscription(
        address vrfCoordinator
    ) public returns (uint256, address) {
        vm.startBroadcast();
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();

        return (subId, vrfCoordinator);
    }

    function run() public {
        generateSubscription();
    }
}

contract FundSubscription is Script, Constants {
    uint256 private constant FUND_AMOUNT = 10 ether; // 10 LINK

    function createSubscription() internal {
        HelperConfig config = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = config.getConfig();

        // Apparently accessing the property directly will not return the object
        address vrfCoordinator = networkConfig.vrfCoordinator;
        uint256 subscriptionId = networkConfig.subscriptionId;
        address linkTokenContract = networkConfig.link;
        fundSubscription(vrfCoordinator, subscriptionId, linkTokenContract);
    }

    function fundSubscription(
        address vrfCoordinator,
        uint256 subId,
        address linkContract
    ) public {
        if (block.chainid == ANVIL_CHAIN_ID) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(
                subId,
                1 ether
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            LinkToken(linkContract).transferAndCall(
                vrfCoordinator,
                1 ether,
                abi.encode(subId)
            );
            vm.stopBroadcast();
        }
    }

    function run() external {
        createSubscription();
    }
}

contract AddConsumer is Script {
    function addContractAsConsumer(address deployedContract) internal {
        HelperConfig config = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = config.getConfig();
        address vrfCoordinator = networkConfig.vrfCoordinator;
        uint256 subscriptionId = networkConfig.subscriptionId;
        enrollConsumer(vrfCoordinator, deployedContract, subscriptionId);
    }

    function enrollConsumer(
        address vrfCoordinator,
        address consumerContract,
        uint256 subId
    ) public {
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(
            subId,
            consumerContract
        );
        vm.stopBroadcast();
    }

    function run() external {
        address recentlyDeployedContract = DevOpsTools
            .get_most_recent_deployment("Lottery", block.chainid);
        addContractAsConsumer(recentlyDeployedContract);
    }
}
