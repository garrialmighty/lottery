// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mock/LinkToken.sol";

abstract contract Constants {
    // Mock VRF Values
    uint96 public constant MOCK_BASE_FEE = 0.025 ether;
    uint96 public constant MOCK_GAS_PRICE = 1e10;
    int256 public constant MOCK_WEI_PER_UNIT_LINK = 4e17;

    uint256 public constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant ANVIL_CHAIN_ID = 31337;
}

error HelperConfig_UnsupportedChainId();

contract HelperConfig is Script, Constants {
    NetworkConfig public activeNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) private configs;

    struct NetworkConfig {
        address vrfCoordinator;
        bytes32 keyHash;
        uint256 subscriptionId;
        uint32 gasLimit;
        uint256 interval;
        address link;
        address account;
    }

    constructor() {
        configs[SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
    }

    function getConfigByChainId(
        uint256 chainId
    ) internal returns (NetworkConfig memory) {
        if (chainId == ANVIL_CHAIN_ID) {
            return getAnvilEthConfig();
        }

        NetworkConfig memory config = configs[chainId];
        if (config.vrfCoordinator == address(0)) {
            revert HelperConfig_UnsupportedChainId();
        }

        return config;
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getSepoliaEthConfig() private pure returns (NetworkConfig memory) {
        // Values taken from https://docs.chain.link/vrf/v2-5/supported-networks
        NetworkConfig memory sepoliaConfig = NetworkConfig({
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            keyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subscriptionId: 21696582914931907414860541822315855792894493028648821595705788130624572580909,
            gasLimit: 500000,
            interval: 86400, // 1 day (24 hours),
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            account: 0xD13Df36b7CF771f0Ea2C1f4b89bF2A00f86BDfaD
        });
        return sepoliaConfig;
    }

    function getAnvilEthConfig() private returns (NetworkConfig memory) {
        if (activeNetworkConfig.vrfCoordinator != address(0)) {
            return activeNetworkConfig;
        }

        vm.startBroadcast();
        VRFCoordinatorV2_5Mock coordinator = new VRFCoordinatorV2_5Mock(
            MOCK_BASE_FEE,
            MOCK_GAS_PRICE,
            MOCK_WEI_PER_UNIT_LINK
        );
        uint256 subId = coordinator.createSubscription();
        LinkToken mockLinkContract = new LinkToken();
        vm.stopBroadcast();

        activeNetworkConfig = NetworkConfig({
            vrfCoordinator: address(coordinator),
            keyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            // TODO: add actual subscription id
            subscriptionId: 0,
            gasLimit: 500000,
            interval: 20, // 20 seconds
            link: address(mockLinkContract),
            account: 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
        });
        return activeNetworkConfig;
    }
}
