pragma solidity ^0.8.0;

abstract contract ICartoons {
    function whitelistMint(bytes32[] calldata _proof, uint256 _amt) virtual external payable;
    function publicMint(uint256 _amt) virtual external payable;
}