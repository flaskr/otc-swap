pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Stub is ERC20 {
    constructor() ERC20("StubToken", "STUB") {
        _mint(msg.sender, 1000000);
    }
}