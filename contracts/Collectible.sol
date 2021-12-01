//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Collectible is ERC721, Ownable {

    using Counters for Counters.Counter;

    Counters.Counter public tokenCounter;

    constructor() ERC721 ("Marko", "MAR") {}

    function createCollectible(address _to) public onlyOwner returns (uint256) {
        uint256 newItemId = tokenCounter.current();
        _safeMint(_to, newItemId);
        tokenCounter.increment();
        return newItemId;
    }

}