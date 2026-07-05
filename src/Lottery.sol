// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";

/**
 * @title A simple raffle contract
 * @author Garri Adrian Nablo
 * @notice This is a simple raffle contract
 */
contract Lottery is VRFConsumerBaseV2Plus, AutomationCompatibleInterface {
    error Lottery_NotOwner();
    error Lottery_ValueBelowEntryFee();
    error Lottery_NotTimeToPickWinner(uint256 prizePool, uint256 playerCount);

    uint256 private constant ENTRY_FEE = 10e18;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant MAX_WORD_NUMBER = 1;
    address private immutable I_OWNER;
    bytes32 private immutable I_KEYHASH;
    uint256 private immutable I_SUBSCRIPTIONID;
    uint32 private immutable I_GASLIMIT;
    uint256 private immutable I_INTERVAL;
    address payable[] private sParticipants;
    uint256 private sLastTimeStamp;

    event LotteryEntered(address indexed participant);
    event RequestRandomNumberForLottery(uint256 requestId);

    /**
     * When we are inheriting from a contract (VRFConsumerBaseV2Plus)
     * and that constract has a constructor, we need to add
     * the inherited contract's constructor arguments to our contract's (Lottery) constructor.
     *
     * @param vrfCoordinator address of VRFCoordinator contract
     * @param keyHash maximum gas price you are willing to pay for a request in wei.
     * It functions as an ID of the offchain VRF job that runs in response to requests.
     * @param subscriptionId subscription ID that this contract uses for funding VRF requests
     * @param gasLimit limit for how much gas to use for the `fulfillRandomWords` callback request.
     * It must be less than the `maxGasLimit` on the coordinator contract.
     * If the `callbackGasLimit` is not sufficient, the callback will fail the subscription is still charged for the work done to generate your requested random values.
     * @param interval rate (in seconds) at which the a lottery winner is picked
     */
    constructor(
        address vrfCoordinator,
        bytes32 keyHash,
        uint256 subscriptionId,
        uint32 gasLimit,
        uint256 interval
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        I_OWNER = msg.sender;
        I_KEYHASH = keyHash;
        I_SUBSCRIPTIONID = subscriptionId;
        I_GASLIMIT = gasLimit;
        I_INTERVAL = interval;
        sLastTimeStamp = block.timestamp;
    }

    function getOwner() public view returns (address) {
        return I_OWNER;
    }

    function getEntryFee() public pure returns (uint256) {
        return ENTRY_FEE;
    }

    function getParticipantAtIndex(
        uint256 index
    ) public view returns (address) {
        return sParticipants[index];
    }

    function enterRaffle() public payable {
        if (msg.value < ENTRY_FEE) {
            revert Lottery_ValueBelowEntryFee();
        }

        sParticipants.push(payable(msg.sender));
        emit LotteryEntered(msg.sender);
    }

    /**
     * This is the callback function that will be called by a Chainlink Automation node.
     * This determines if it's time for the `Lottery` smart contract to pick a winner or not.
     *
     * @return upkeepNeeded flag to trigger if it's time to pick a winner
     */
    function checkUpkeep(
        bytes memory /* checkData */
    )
        public
        view
        override
        returns (bool upkeepNeeded, bytes memory /* performData */)
    {
        bool hasPlayers = sParticipants.length > 0;
        bool isTimeToPickWinner = (block.timestamp - sLastTimeStamp) >
            I_INTERVAL;
        upkeepNeeded = isTimeToPickWinner && hasPlayers;
        return (upkeepNeeded, "");
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Lottery_NotTimeToPickWinner(
                address(this).balance,
                sParticipants.length
            );
        }

        VRFV2PlusClient.RandomWordsRequest memory payload = VRFV2PlusClient
            .RandomWordsRequest({
                keyHash: I_KEYHASH,
                subId: I_SUBSCRIPTIONID,
                callbackGasLimit: I_GASLIMIT,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                numWords: MAX_WORD_NUMBER,
                // Setting `nativePayment` to true to pay for VRF requests with Sepolia ETH instead of LINK
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: true})
                )
            });
        // `s_vrfCoordinator` is an inherited state variable of VRFConsumerBaseV2Plus
        uint256 requestId = s_vrfCoordinator.requestRandomWords(payload);
        emit RequestRandomNumberForLottery(requestId);
    }

    function fulfillRandomWords(
        uint256 /* requestId */,
        uint256[] calldata randomWords
    ) internal virtual override {
        uint256 winnderIndex = randomWords[0] % sParticipants.length;
        address payable raffleWinner = sParticipants[winnderIndex];
        uint256 totalPrize = address(this).balance;
        (bool isTransferSuccessful, ) = raffleWinner.call{value: totalPrize}(
            ""
        );

        require(isTransferSuccessful, "Prize sending failed");
    }
}
