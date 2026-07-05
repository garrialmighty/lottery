// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

import {Lottery} from "../src/Lottery.sol";
import {LotteryDeploy} from "../script/Lottery.s.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";

contract LotteryTest is Test {
    address donorUser = makeAddr("mockUser");
    Lottery private lottery;
    address private vrfCoordinator;
    HelperConfig.NetworkConfig private networkConfig;

    // As per tutorial, we have to copy-paste the event form the contract.
    event LotteryEntered(address indexed participant);

    modifier lotteryEntered() {
        uint256 entryFee = lottery.getEntryFee();
        vm.prank(donorUser);
        lottery.enterRaffle{value: entryFee}();
        _;
    }

    function setUp() external {
        LotteryDeploy deployLottery = new LotteryDeploy();
        (lottery, networkConfig) = deployLottery.run();
        vm.deal(donorUser, 10 ether);
        vrfCoordinator = networkConfig.vrfCoordinator;
    }

    function test_getEntryFee() external view {
        uint256 entryFee = lottery.getEntryFee();
        assertEq(entryFee, 10e18);
    }

    function test_minimumEntryFee() external {
        vm.expectRevert(Lottery.Lottery_ValueBelowEntryFee.selector);
        lottery.enterRaffle();
    }

    function test_raffleEntry() external {
        uint256 entryFee = lottery.getEntryFee();

        // Always set prank before sending value
        vm.prank(donorUser);
        // We tell Foundry that we are expecting an event
        vm.expectEmit(true, false, false, false, address(lottery));
        // We also tell Foundry this is the type of event we are expecting
        emit LotteryEntered(donorUser);
        lottery.enterRaffle{value: entryFee}();

        address participant = lottery.getParticipantAtIndex(0);
        assertEq(participant, donorUser);
    }

    function test_upkeepHandling() external lotteryEntered {
        (bool falseUpkeep, ) = lottery.checkUpkeep("");
        assertFalse(falseUpkeep);

        // Interval is 20 seconds.
        // Check `HelperConfig.s.sol`
        vm.warp(block.timestamp + 60);
        // Also simulate that a new block has been added in the chain, as a best practice
        vm.roll(block.number + 1);
        (bool trueUpkeep, ) = lottery.checkUpkeep("");
        assertTrue(trueUpkeep);
    }

    function test_performingUpkeep_notTime() external lotteryEntered {
        bytes memory expectedError = abi.encodeWithSelector(
            Lottery.Lottery_NotTimeToPickWinner.selector,
            lottery.getEntryFee(),
            1
        );
        vm.expectRevert(expectedError);
        lottery.performUpkeep("");
    }

    function test_performUpkeep_timeToPickWinner() external lotteryEntered {
        vm.warp(block.timestamp + 60);
        vm.roll(block.number + 1);

        // It is important to call `recordLogs`
        // before calling a function that emits events
        // Not calling this will result in `getRecordedLogs` returning empty.
        vm.recordLogs();
        lottery.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[0].topics[0];
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            uint256(1),
            address(lottery)
        );

        assertEq(address(lottery).balance, 0);
    }
}
