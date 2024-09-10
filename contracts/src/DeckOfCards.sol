// SPDX-License-Identifier: MIT
// An example of a consumer contract that relies on a subscription for funding.
pragma solidity ^0.8.7;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import {Cards} from "./Cards.sol";

/**
 * @title Deck of Cards
 * @notice A contract that you can use as a deck of cards in your game
 */
contract DeckOfCards is VRFConsumerBaseV2 {
    Cards public cardCollection;  

    struct Deck {
        uint8 numDecks;
        uint256[] cardIds;
        address[] authorizedPlayers;
    }
    uint256 public deckCounter;

    mapping (uint256 deckId => Deck) private decks;
    mapping (uint256 deckId => uint256 randomnessRequestId) public randomnessRequests;

    //====================================
    //     Chainlink VRF variables
    //====================================
    VRFCoordinatorV2Interface immutable COORDINATOR;

    // Your subscription ID.
    uint64 immutable s_subscriptionId;

    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/docs/vrf-contracts/#configurations
    bytes32 immutable s_keyHash;

    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Storing each word costs about 20,000 gas,
    // so 100,000 is a safe default for this example contract. Test and adjust
    // this limit based on the network that you select, the size of the request,
    // and the processing of the callback request in the fulfillRandomWords()
    // function.
    uint32 constant CALLBACK_GAS_LIMIT = 100000;

    // The default is 3, but you can set this higher.
    uint16 constant REQUEST_CONFIRMATIONS = 3;

    // For this example, retrieve 2 random values in one request.
    // Cannot exceed VRFCoordinatorV2.MAX_NUM_WORDS.
    uint32 constant NUM_WORDS = 2;

    uint256[] public s_randomWords;
    uint256 public s_requestId;
    address s_owner;

    event ReturnedRandomness(uint256[] randomWords);

    /**
     * @notice Constructor inherits VRFConsumerBaseV2
     *
     * @param subscriptionId - the subscription ID that this contract uses for funding requests
     * @param vrfCoordinator - coordinator, check https://docs.chain.link/docs/vrf-contracts/#configurations
     * @param keyHash - the gas lane to use, which specifies the maximum gas price to bump to
     */
    constructor(
        Cards _cardCollection,
        uint64 subscriptionId,
        address vrfCoordinator,
        bytes32 keyHash
    ) VRFConsumerBaseV2(vrfCoordinator) {
        cardCollection = _cardCollection;

        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        s_keyHash = keyHash;
        s_owner = msg.sender;
        s_subscriptionId = subscriptionId;
    }

    function createNewDeck(uint8 numDecks, address[] memory authorizedPlayers) external returns (uint256 deckId) {
        deckId = deckCounter++;
        uint256 expectedNumCards = 52 * numDecks;
        Deck memory newDeck = Deck(
            numDecks, 
            new uint256[](expectedNumCards), 
            authorizedPlayers
        );

        uint256[] memory cardIds = new uint256[](expectedNumCards);
        for (uint256 i = 0; i < expectedNumCards; i++) {
            cardIds[i] = i + 1;
        }
        newDeck.cardIds = cardIds;
        decks[deckId] = newDeck;

        return deckId;
    }

    /**
     * @notice Requests randomness
     * Assumes the subscription is funded sufficiently; "Words" refers to unit of data in Computer Science
     */
    function requestRandomWords() external onlyOwner {
        // Will revert if subscription is not set and funded.
        s_requestId = COORDINATOR.requestRandomWords(
            s_keyHash,
            s_subscriptionId,
            REQUEST_CONFIRMATIONS,
            CALLBACK_GAS_LIMIT,
            NUM_WORDS
        );
    }

    /**
     * @notice Callback function used by VRF Coordinator
     *
     * @param  - id of the request
     * @param randomWords - array of random results from VRF Coordinator
     */
    function fulfillRandomWords(
        uint256 /* requestId */,
        uint256[] memory randomWords
    ) internal override {
        s_randomWords = randomWords;
        emit ReturnedRandomness(randomWords);
    }

    modifier onlyOwner() {
        require(msg.sender == s_owner);
        _;
    }

    function getDeck(uint256 deckId) public view returns (Deck memory) {
        return decks[deckId];
    }
}
