// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.27;

import {DeckOfCards} from "../src/DeckOfCards.sol";
import {Test} from "../lib/forge-std/src/Test.sol";
import {VRFCoordinatorV2Mock} from "../src/VRFCoordinatorV2Mock.sol";

contract DeckOfCardsTest is Test {
    DeckOfCards public deckOfCards;
    VRFCoordinatorV2Mock public vrfCoordinator;
    bytes32 private constant KEY_HASH = 0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc;

    address public player1 = address(1);
    address public player2 = address(2);
    address public player3 = address(3);

    function setUp() public {
        vm.deal(player1, 10 ether);
        vm.deal(player2, 10 ether);
        vm.deal(player3, 10 ether);

        vrfCoordinator = new VRFCoordinatorV2Mock(
            100000000000000000, // fee
            1000000000 // gas price
        );
        uint64 subscriptionId = vrfCoordinator.createSubscription();
        // fund the subscription
        vrfCoordinator.fundSubscription(subscriptionId, 1 ether);
        deckOfCards = new DeckOfCards(
            subscriptionId,
            address(vrfCoordinator),
            KEY_HASH
        );
        vrfCoordinator.addConsumer(
            subscriptionId,
            address(deckOfCards)
        );
    }

    function testCreateNewDeck() public {
        address[] memory authorizedDealers = new address[](1);
        authorizedDealers[0] = player1;
        uint256 totalCards = 52; // Standard deck size, but can be any number
        uint256 deckId = deckOfCards.createNewDeck(authorizedDealers, totalCards);
        assertTrue(deckId == 0);
        address[] memory authorizedDealersFromContract = deckOfCards.getAuthorizedDealers(deckId);
        assertTrue(authorizedDealersFromContract.length == 1);
        assertTrue(deckOfCards.getRemainingDeckCards(deckId).length == totalCards);
    }

    function testDealCards () public {
        address[] memory authorizedDealers = new address[](1);
        authorizedDealers[0] = player1;
        uint256 totalCards = 52;
        uint256 deckId = deckOfCards.createNewDeck(authorizedDealers, totalCards);
        
        uint256 numToDeal = 5;
        address[] memory players = new address[](1);
        players[0] = player1;
        vm.prank(player1);
        DeckOfCards.DealRequest memory dealRequest = DeckOfCards.DealRequest(deckId, numToDeal, players);
        deckOfCards.dealCards(dealRequest);

        uint256 requestId = deckOfCards.decksToRandomnessRequests(deckId);
        vrfCoordinator.fulfillRandomWords(
            requestId, 
            address(deckOfCards)
        );
        assertTrue(deckOfCards.getPlayerCards(deckId, player1).length == numToDeal);
    }

    function createDeckAndDealCards(address dealer, address player, uint256 numToDeal) internal returns (uint256 deckId, uint256 cardId) {
        // Create a new deck
        address[] memory authorizedDealers = new address[](1);
        authorizedDealers[0] = dealer;
        uint256 totalCards = 52;
        deckId = deckOfCards.createNewDeck(authorizedDealers, totalCards);
        
        // Deal cards
        address[] memory players = new address[](1);
        players[0] = player;
        vm.prank(dealer);
        DeckOfCards.DealRequest memory dealRequest = DeckOfCards.DealRequest(deckId, numToDeal, players);
        deckOfCards.dealCards(dealRequest);

        // Fulfill randomness request
        uint256 requestId = deckOfCards.decksToRandomnessRequests(deckId);
        vrfCoordinator.fulfillRandomWords(requestId, address(deckOfCards));

        // Get the dealt card
        uint256[] memory playerCards = deckOfCards.getPlayerCards(deckId, player);
        require(playerCards.length == numToDeal, "Incorrect number of cards dealt");
        cardId = playerCards[0];
    }

    function setupDeckAndDealCard(address dealer, address player) internal returns (uint256 deckId, uint256 cardId) {
        // Create a new deck
        address[] memory authorizedDealers = new address[](1);
        authorizedDealers[0] = dealer;
        uint256 totalCards = 52;
        deckId = deckOfCards.createNewDeck(authorizedDealers, totalCards);
        
        // Deal cards
        uint256 numToDeal = 1;
        address[] memory players = new address[](1);
        players[0] = player;
        vm.prank(dealer);
        DeckOfCards.DealRequest memory dealRequest = DeckOfCards.DealRequest(deckId, numToDeal, players);
        deckOfCards.dealCards(dealRequest);

        // Fulfill randomness request
        uint256 requestId = deckOfCards.decksToRandomnessRequests(deckId);
        vrfCoordinator.fulfillRandomWords(requestId, address(deckOfCards));

        // Get the dealt card
        uint256[] memory playerCards = deckOfCards.getPlayerCards(deckId, player);
        require(playerCards.length == 1, "Player should have 1 card");
        cardId = playerCards[0];
    }

    function testRevealCard() public {
        (uint256 deckId, uint256 cardId) = setupDeckAndDealCard(player1, player2);

        uint8 suit = 1; // Hearts
        uint8 value = 13; // King
        bytes32 message = keccak256(abi.encodePacked(cardId, suit, value));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(2, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.prank(player2);
        deckOfCards.revealCard(deckId, cardId, suit, value, signature);

        (,, bool revealed, uint8 revealedSuit, uint8 revealedValue) = deckOfCards.getCardDetails(cardId);
        assertTrue(revealed, "Card should be revealed");
        assertEq(revealedSuit, suit, "Revealed suit should match");
        assertEq(revealedValue, value, "Revealed value should match");
    }
}
