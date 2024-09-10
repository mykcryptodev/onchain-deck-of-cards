// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.27;

import {DeckOfCards} from "../src/DeckOfCards.sol";
import {Test} from "../lib/forge-std/src/Test.sol";
import {VRFCoordinatorV2Mock} from "../src/VRFCoordinatorV2Mock.sol";
import {Cards} from "../src/Cards.sol";

contract DeckOfCardsTest is Test {
    DeckOfCards public deckOfCards;
    VRFCoordinatorV2Mock public vrfCoordinator;
    Cards public cards;
    bytes32 private constant KEY_HASH = 0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc;

    address public cardCollection;
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
        cards = new Cards(address(deckOfCards));
    }

    function testGetRandomWords () public {
        deckOfCards.requestRandomWords();
        uint256 requestId = deckOfCards.s_requestId();
        vrfCoordinator.fulfillRandomWords(
            requestId, 
            address(deckOfCards)
        );
        uint256 firstRandomWord = deckOfCards.s_randomWords(0);
        uint256 secondRandomWord = deckOfCards.s_randomWords(1);
        // assert that each random word exists
        assertTrue(firstRandomWord > 0);
        assertTrue(secondRandomWord > 0);
    }

    function testCreateNewDeck() public {
        uint8 numDecks = 1;
        uint256 expectedNumCards = 52 * numDecks;
        address[] memory authorizedPlayers = new address[](1);
        authorizedPlayers[0] = player1;
        uint256 deckId = deckOfCards.createNewDeck(numDecks, authorizedPlayers);
        assertTrue(deckId == 0);
        assertTrue(deckOfCards.getDeck(deckId).cardIds.length == expectedNumCards);
    }
}
