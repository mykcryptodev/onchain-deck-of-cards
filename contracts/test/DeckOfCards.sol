// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.27;

import {DeckOfCards} from "../src/DeckOfCards.sol";
import {Test} from "forge-std/Test.sol";

contract GreeterTest is Test {
    DeckOfCards public deckOfCards;

    function setUp() public {
        greeter = new Greeter("Hello, Hardhat!");
    }

    function testCreateGreeter() public {
        assertEq(greeter.greet(), "Hello, Hardhat!");
        greeter.setGreeting("Hola, mundo!");
        assertEq(greeter.greet(), "Hola, mundo!");
    }
}
