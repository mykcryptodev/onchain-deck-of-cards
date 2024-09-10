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
        uint256 expectedNumCards = 52;
        address[] memory authorizedDealers = new address[](1);
        authorizedDealers[0] = player1;
        uint256 deckId = deckOfCards.createNewDeck(authorizedDealers);
        assertTrue(deckId == 0);
        assertTrue(deckOfCards.getDeck(deckId).cardIds.length == expectedNumCards);
    }

    function testGetRandomWords () public {
        address[] memory authorizedDealers = new address[](1);
        uint256 deckId = deckOfCards.createNewDeck(authorizedDealers);
        deckOfCards.requestRandomWords(deckId);
        uint256 requestId = deckOfCards.decksToRandomnessRequests(deckId);
        vrfCoordinator.fulfillRandomWords(
            requestId, 
            address(deckOfCards)
        );
        uint256 randomness = deckOfCards.deckRandomness(0);
        assertTrue(randomness > 0);
    }

    function testDealCards () public {
        address[] memory authorizedDealers = new address[](1);
        authorizedDealers[0] = player1;
        uint256 deckId = deckOfCards.createNewDeck(authorizedDealers);
        deckOfCards.requestRandomWords(deckId);
        uint256 requestId = deckOfCards.decksToRandomnessRequests(deckId);
        vrfCoordinator.fulfillRandomWords(
            requestId, 
            address(deckOfCards)
        );
        uint256 randomness = deckOfCards.deckRandomness(deckId);
        assertTrue(randomness > 0);
        
        uint256 numToDeal = 5;
        address[] memory players = new address[](1);
        players[0] = player1;
        vm.prank(player1);
        deckOfCards.dealCards(deckId, numToDeal, players);
        assertTrue(deckOfCards.getDeck(deckId).cardIds.length == 52 - numToDeal);
        assertTrue(deckOfCards.getPlayerCards(deckId, player1).length == numToDeal);
    }
}
