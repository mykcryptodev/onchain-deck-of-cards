// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract Cards is ERC721, Ownable {
    using ECDSA for bytes32;

    struct Card {
        bytes32 encryptedValue; // Encrypted card value (hash of card)
        bool revealed;
        string revealedValue; // Once revealed, store the value here
        uint256 deckId; // The deck this card belongs to
    }

    // Mapping from tokenId to Card metadata
    mapping(uint256 => Card) private _cardData;

    // Event to log the reveal
    event CardRevealed(uint256 tokenId, string revealedValue);

    constructor(address _owner) ERC721("CardDeckNFT", "CDNFT") Ownable(_owner) {}

    // Mint a card with encrypted metadata
    function mintCard(address to, uint256 tokenId, uint256 deckId, bytes32 encryptedValue) external onlyOwner {
        _safeMint(to, tokenId);
        _cardData[tokenId] = Card({
            encryptedValue: encryptedValue,
            revealed: false,
            revealedValue: "",
            deckId: deckId
        });
    }

    // Function for the token owner to view their card value (encrypted)
    function getEncryptedCardValue(uint256 tokenId) external view returns (bytes32) {
        require(ownerOf(tokenId) == msg.sender, "You are not the owner of this card");
        
        return _cardData[tokenId].encryptedValue;
    }

    // Function to reveal the card
    function revealCard(uint256 tokenId, string memory revealedValue, bytes memory ownerSignature) external {
        require(ownerOf(tokenId) == msg.sender, "Only the owner can reveal the card");
        require(!_cardData[tokenId].revealed, "Card is already revealed");

        // Verify the owner’s signature matches the revealed value
        bytes32 messageHash = keccak256(abi.encodePacked(revealedValue, tokenId));
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        address signer = ECDSA.recover(ethSignedMessageHash, ownerSignature);
        require(signer == msg.sender, "Invalid signature");

        // Mark the card as revealed and store the value
        _cardData[tokenId].revealed = true;
        _cardData[tokenId].revealedValue = revealedValue;

        emit CardRevealed(tokenId, revealedValue);
    }

    // Function to view the revealed value (if revealed)
    function getRevealedCardValue(uint256 tokenId) external view returns (string memory) {
        require(_cardData[tokenId].revealed, "Card is not revealed yet");

        return _cardData[tokenId].revealedValue;
    }
}
