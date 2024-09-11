// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

import "hardhat/console.sol";

contract DeckOfCards is VRFConsumerBaseV2 {
    using EnumerableSet for EnumerableSet.UintSet;
    using ECDSA for bytes32;

    struct Deck {
        EnumerableSet.UintSet cardIds;
        address[] authorizedDealers;
        uint256 totalCards;
    }

    struct Card {
        bytes encryptedValue;
        address dealerPublicKey;
        bool revealed;
        uint8 suit;
        uint8 value;
        uint256 deckId;
    }

    struct DealRequest {
        uint256 deckId;
        uint256 numCardsEach;
        address[] players;
    }

    uint256 public deckCounter;
    uint256 public cardCounter;

    mapping(uint256 deckId => Deck deck) private decks; // mapping deckId to Deck struct
    mapping(uint256 deckId => mapping(address player => EnumerableSet.UintSet cardIds)) private playerCards; // mapping deckId and player address to a set of card IDs
    mapping(uint256 cardId => Card card) public cards; // mapping cardId to Card struct

    // Chainlink VRF variables
    VRFCoordinatorV2Interface immutable COORDINATOR;
    uint64 immutable s_subscriptionId;
    bytes32 immutable s_keyHash;
    uint32 constant CALLBACK_GAS_LIMIT = 1000000;
    uint16 constant REQUEST_CONFIRMATIONS = 3;
    uint32 constant NUM_WORDS = 1;

    mapping(uint256 requestId => uint256 deckId) public randomnessRequestsToDecks; // mapping randomness request ID to deckId
    mapping(uint256 deckId => uint256 requestId) public decksToRandomnessRequests; // mapping deckId to randomness request ID
    mapping(uint256 deckId => uint256 randomness) public deckRandomness; // mapping deckId to randomness value
    mapping(uint256 deckId => DealRequest request) public dealRequests; // mapping deckId to DealRequest struct

    event DeckCreated(uint256 indexed deckId);
    event CardDealt(uint256 indexed deckId, address indexed player, uint256 cardId);
    event CardsDealt(uint256 indexed deckId);
    event CardRevealed(uint256 indexed cardId, uint8 suit, uint8 value);
    event ReturnedRandomness(uint256[] randomWords);

    error NotAuthorized();

    modifier isAuthorizedDealer(uint256 deckId) {
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

    constructor(
        uint64 subscriptionId,
        address vrfCoordinator,
        bytes32 keyHash
    ) VRFConsumerBaseV2(vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        s_keyHash = keyHash;
        s_subscriptionId = subscriptionId;
    }

    function createNewDeck(address[] memory authorizedDealers, uint256 totalCards) external returns (uint256 deckId) {
        deckId = deckCounter++;

        Deck storage newDeck = decks[deckId];
        newDeck.authorizedDealers = authorizedDealers;
        newDeck.totalCards = totalCards;

        // Initialize the deck with the specified number of cards
        for (uint256 i = 0; i < totalCards; i++) {
            uint256 cardId = cardCounter++;
            newDeck.cardIds.add(cardId);
            cards[cardId] = Card({
                encryptedValue: "",
                dealerPublicKey: address(0),
                revealed: false,
                suit: 0,
                value: 0,
                deckId: deckId
            });
        }

        emit DeckCreated(deckId);
        return deckId;
    }

    function dealCards(DealRequest memory dealRequest) external isAuthorizedDealer(dealRequest.deckId) {
        _requestRandomWords(dealRequest);
    }

    function _dealRandomCards(DealRequest memory dealRequest) private {
        uint256 deckId = dealRequest.deckId;
        uint256 numCardsEach = dealRequest.numCardsEach;
        address[] memory players = dealRequest.players;
        Deck storage deck = decks[deckId];
        require(deck.cardIds.length() >= numCardsEach * players.length, "Not enough cards in the deck");
        
        uint256 randomness = deckRandomness[deckId];
        require(randomness != 0, "Randomness not yet returned");

        for (uint256 i = 0; i < players.length; i++) {
            for (uint256 j = 0; j < numCardsEach; j++) {
                uint256 randomIndex = uint256(keccak256(abi.encodePacked(randomness, block.timestamp, i, j))) % deck.cardIds.length();
                uint256 cardId = deck.cardIds.at(randomIndex);

                // Create an encrypted card
                bytes memory encryptedValue = _encryptCard(cardId, players[i]);
                cards[cardId] = Card({
                    encryptedValue: encryptedValue,
                    dealerPublicKey: msg.sender,
                    revealed: false,
                    suit: 0,
                    value: 0,
                    deckId: deckId
                });

                // Deal the card to the player
                playerCards[deckId][players[i]].add(cardId);
                
                // Remove the card from the deck
                deck.cardIds.remove(cardId);

                emit CardDealt(deckId, players[i], cardId);
            }
        }

        emit CardsDealt(deckId);

        delete deckRandomness[deckId];
    }

    function _encryptCard(uint256 cardId, address player) private view returns (bytes memory) {
        // Placeholder encryption
        return abi.encodePacked(keccak256(abi.encodePacked(cardId, player, block.timestamp)));
    }

    function revealCard(uint256 deckId, uint256 cardId, uint8 suit, uint8 value, bytes memory playerSignature) external {
        require(cardId < 52, "Invalid card ID");
        require(!cards[cardId].revealed, "Card already revealed");

        address player = msg.sender;
        require(playerCards[deckId][player].contains(cardId), "Not your card");

        bytes32 message = keccak256(abi.encodePacked(cardId, suit, value));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));
        address signer = ethSignedMessageHash.recover(playerSignature);

        require(signer == player, "Invalid signature");

        Card storage card = cards[cardId];
        card.revealed = true;
        card.suit = suit;
        card.value = value;

        emit CardRevealed(cardId, suit, value);
    }

    function _requestRandomWords(DealRequest memory dealRequest) private {
        uint256 requestId = COORDINATOR.requestRandomWords(
            s_keyHash,
            s_subscriptionId,
            REQUEST_CONFIRMATIONS,
            CALLBACK_GAS_LIMIT,
            NUM_WORDS
        );
        randomnessRequestsToDecks[requestId] = dealRequest.deckId;
        decksToRandomnessRequests[dealRequest.deckId] = requestId;
        dealRequests[requestId] = dealRequest;
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        uint256 deckId = randomnessRequestsToDecks[requestId];
        deckRandomness[deckId] = randomWords[0];

        DealRequest memory dealRequest = dealRequests[requestId];
        _dealRandomCards(dealRequest);

        emit ReturnedRandomness(randomWords);

        delete randomnessRequestsToDecks[requestId];
        delete decksToRandomnessRequests[deckId];
        delete dealRequests[requestId];
    }

    function getPlayerCards(uint256 deckId, address player) public view returns (uint256[] memory) {
        EnumerableSet.UintSet storage playerHand = playerCards[deckId][player];
        uint256[] memory _cards = new uint256[](playerHand.length());
        for (uint256 i = 0; i < playerHand.length(); i++) {
            _cards[i] = playerHand.at(i);
        }
        return _cards;
    }

    function getRemainingDeckCards(uint256 deckId) public view returns (uint256[] memory) {
        Deck storage deck = decks[deckId];
        uint256[] memory remainingCards = new uint256[](deck.cardIds.length());
        for (uint256 i = 0; i < deck.cardIds.length(); i++) {
            remainingCards[i] = deck.cardIds.at(i);
        }
        return remainingCards;
    }

    function getCardDetails(uint256 cardId) public view returns (
        bytes memory encryptedValue,
        address dealerPublicKey,
        bool revealed,
        uint8 suit,
        uint8 value
    ) {
        Card storage card = cards[cardId];
        return (card.encryptedValue, card.dealerPublicKey, card.revealed, card.suit, card.value);
    }

    function getAuthorizedDealers(uint256 deckId) public view returns (address[] memory) {
        return decks[deckId].authorizedDealers;
    }
}