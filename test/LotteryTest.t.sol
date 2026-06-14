// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {console, Test} from "forge-std/Test.sol";
import {Lottery} from "../src/Lottery.sol";
import {LotteryDeploy} from "../script/Lottery.s.sol";

contract LotteryTest is Test {
    Lottery lottery;
    address DONOR_USER = makeAddr("mockUser");

    // As per tutorial, we have to copy-paste the event form the contract.
    event LotteryEntered(address indexed participant);

    modifier lotteryEntered() {
        uint256 entryFee = lottery.getEntryFee();
        vm.prank(DONOR_USER);
        lottery.enterRaffle{value: entryFee}();
        _;
    }

    function setUp() external {
        LotteryDeploy deployLottery = new LotteryDeploy();
        lottery = deployLottery.run();
        vm.deal(DONOR_USER, 10 ether);
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
        vm.prank(DONOR_USER);
        // We tell Foundry that we are expecting an event
        vm.expectEmit(true, false, false, false, address(lottery));
        // We also tell Foundry this is the type of event we are expecting
        emit LotteryEntered(DONOR_USER);
        lottery.enterRaffle{value: entryFee}();

        address participant = lottery.getParticipantAtIndex(0);
        assertEq(participant, DONOR_USER);
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
}
