// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.27;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract Cards is ERC721 {
    using Strings for uint256;

    enum Suit {
        HEARTS,
        DIAMONDS,
        CLUBS,
        SPADES
    }

    uint256 public constant MAX_SUPPLY = 52;
    uint256 public totalSupply;

    mapping(uint256 => Suit) public tokenIdToSuit;
    mapping(uint256 => uint8) public tokenIdToValue;

    constructor() ERC721("Card NFT", "CARD") {
        for (uint256 tokenId = 0; tokenId < MAX_SUPPLY; tokenId++) {
            uint8 value = uint8(tokenId % 13 + 1);
            Suit suit = Suit(tokenId / 13);

            _mint(msg.sender, tokenId);
            tokenIdToSuit[tokenId] = suit;
            tokenIdToValue[tokenId] = value;

            totalSupply++;
        }
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(tokenId < MAX_SUPPLY, "Card does not exist");

        string memory suitSymbol;
        if (tokenIdToSuit[tokenId] == Suit.HEARTS) {
            suitSymbol = "H";
        } else if (tokenIdToSuit[tokenId] == Suit.DIAMONDS) {
            suitSymbol = "D";
        } else if (tokenIdToSuit[tokenId] == Suit.CLUBS) {
            suitSymbol = "C";
        } else {
            suitSymbol = "S";
        }

        string memory valueString;
        if (tokenIdToValue[tokenId] == 1) {
            valueString = "A";
        } else if (tokenIdToValue[tokenId] == 11) {
            valueString = "J";
        } else if (tokenIdToValue[tokenId] == 12) {
            valueString = "Q";
        } else if (tokenIdToValue[tokenId] == 13) {
            valueString = "K";
        } else {
            uint256 valueUint256 = uint256(tokenIdToValue[tokenId]);
            valueString = valueUint256.toString();
        }

        return string.concat(valueString, suitSymbol);
    }
}
