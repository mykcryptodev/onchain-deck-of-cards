// SPDX-License-Identifier: MIT
// An example of a consumer contract that relies on a subscription for funding.
pragma solidity ^0.8.7;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

/**
 * @title Deck of Cards
 * @notice A contract that you can use as a deck of cards in your game
 */
contract DeckOfCards is VRFConsumerBaseV2 {
    struct Deck {
        uint256[] cardIds; // 0 is Ace of Spades, 1 is 2 of Spades, ..., 51 is King of Diamonds
        address[] authorizedDealers;
    }
    uint256 public deckCounter;

    mapping (uint256 deckId => Deck) private decks;
    mapping (uint256 deckId => mapping(address player => uint256[] cardIds)) public playerCards;

    mapping (uint256 randomnessRequestId => uint256 deckId) public randomnessRequestsToDecks;
    mapping (uint256 deckId => uint256 randomnessRequestId) public decksToRandomnessRequests;
    mapping (uint256 deckId => uint256 randomness) public deckRandomness;

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

    // For this example, retrieve 1 random value in one request.
    // Cannot exceed VRFCoordinatorV2.MAX_NUM_WORDS.
    uint32 constant NUM_WORDS = 1;

    uint256[] public s_randomWords;
    address s_owner;

    event ReturnedRandomness(uint256[] randomWords);
    
    error NotAuthorized();

    modifier isAuthorizedDealer (uint256 deckId) {
        bool authorized = false;
        for (uint256 i = 0; i < decks[deckId].authorizedDealers.length; i++) {
            if (decks[deckId].authorizedDealers[i] == msg.sender) {
                authorized = true;
                break;
            }
        }
        if (!authorized) {
            revert NotAuthorized();
        }
        _;
    }

    /**
     * @notice Constructor inherits VRFConsumerBaseV2
     *
     * @param subscriptionId - the subscription ID that this contract uses for funding requests
     * @param vrfCoordinator - coordinator, check https://docs.chain.link/docs/vrf-contracts/#configurations
     * @param keyHash - the gas lane to use, which specifies the maximum gas price to bump to
     */
    constructor(
        uint64 subscriptionId,
        address vrfCoordinator,
        bytes32 keyHash
    ) VRFConsumerBaseV2(vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        s_keyHash = keyHash;
        s_owner = msg.sender;
        s_subscriptionId = subscriptionId;
    }

    function createNewDeck(address[] memory authorizedDealers) external returns (uint256 deckId) {
        deckId = deckCounter++;

        // Initialize the deck with 52 cards
        uint256[] memory cardIds = new uint256[](52);
        for (uint256 i = 0; i < 52; i++) {
            cardIds[i] = i;
        }

        Deck memory newDeck = Deck(
            cardIds,
            authorizedDealers
        );

        decks[deckId] = newDeck;

        return deckId;
    }

    function dealCards(uint256 deckId, uint256 numCardsEach, address[] memory players) external {
        Deck storage deck = decks[deckId];
        require(deck.cardIds.length >= numCardsEach * players.length, "Not enough cards in the deck");
        
        uint256 randomness = deckRandomness[deckId];
        require(randomness != 0, "Randomness not yet returned");

        uint256 remainingCards = deck.cardIds.length;

        for (uint256 i = 0; i < players.length; i++) {
            for (uint256 j = 0; j < numCardsEach; j++) {
                // Generate a random index
                uint256 randomIndex = uint256(keccak256(abi.encodePacked(randomness, block.timestamp, i, j))) % remainingCards;
                uint256 cardId = deck.cardIds[randomIndex];

                // give the card to the player
                playerCards[deckId][players[i]].push(cardId);
                
                // Remove the dealt card by replacing it with the last card in the array
                deck.cardIds[randomIndex] = deck.cardIds[remainingCards - 1];
                deck.cardIds.pop();  // Remove the last card (now redundant)
                remainingCards--;
            }
        }

        // delete the randomness value so that it cannot be used again
        delete deckRandomness[deckId];
    }
    
    /**
     * @notice Requests randomness
     * Assumes the subscription is funded sufficiently; "Words" refers to unit of data in Computer Science
     */
    function requestRandomWords(uint256 deckId) external onlyOwner {
        // Will revert if subscription is not set and funded.
        uint256 requestId = COORDINATOR.requestRandomWords(
            s_keyHash,
            s_subscriptionId,
            REQUEST_CONFIRMATIONS,
            CALLBACK_GAS_LIMIT,
            NUM_WORDS
        );
        randomnessRequestsToDecks[requestId] = deckId;
        decksToRandomnessRequests[deckId] = requestId;
    }

    /**
     * @notice Callback function used by VRF Coordinator
     *
     * @param requestId  - id of the request
     * @param randomWords - array of random results from VRF Coordinator
     */
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        uint256 deckId = randomnessRequestsToDecks[requestId];
        deckRandomness[deckId] = randomWords[0];
        emit ReturnedRandomness(randomWords);

        delete randomnessRequestsToDecks[requestId];
        delete decksToRandomnessRequests[deckId];
    }

    modifier onlyOwner() {
        require(msg.sender == s_owner);
        _;
    }

    function getDeck(uint256 deckId) public view returns (Deck memory) {
        return decks[deckId];
    }

    function getPlayerCards (uint256 deckId, address player) public view returns (uint256[] memory) {
        return playerCards[deckId][player];
    }
}
