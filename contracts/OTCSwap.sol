//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "hardhat/console.sol";

/**
 * Contract for creating over-the-counter ERC20 swap between 2 tokens.
 * Receipeint addresses are fixed, funder's address is advised but anyone can fund the legs.
 * Once all legs of a swap are funded, the contract will send the tokens deposit into each leg to the target receipient.
 * If you overfund a leg, the extra amount will be added contract's surplus funds, and the swap will still occur.
 */
contract OTCSwap {

    // For handling ERC20, check https://ethereum.org/en/developers/tutorials/transfers-and-approval-of-erc-20-tokens-from-a-solidity-smart-contract/

    uint32 swapIdCount;
    mapping(uint32 => Swap) swapsById;
    mapping(address => uint256) tokenSurpluses;

    /**
     * Holds the state for a swap between 2 receipients.
     */
    struct Swap {
        uint32 id;
        SwapLeg leg1;
        SwapLeg leg2;
    }

    /**
     * Represents one leg of a swap.
     */
    struct SwapLeg {
        address receipientAddress;
        address tokenAddress;
        uint256 targetFundingAmount;
        uint256 depositSoFar;
    }

    event SwapCreated(uint32 id,
                      address leg1Receipient,
                      address leg1TokenAddress,
                      uint256 leg1TargetAmount,
                      address leg2Receipient,
                      address leg2TokenAddress,
                      uint256 leg2TargetAmount);
    

    constructor() {
        // init id count
        swapIdCount = 0;
    }

    function createNewSwap(address leg1Receipient, 
                            address leg1TokenAddress, 
                            uint256 leg1TargetAmount,
                            address leg2Receipient, 
                            address leg2TokenAddress, 
                            uint256 leg2TargetAmount) external {
        swapIdCount++;
        uint32 newId = swapIdCount;
        swapsById[newId] = Swap(
            newId, 
            SwapLeg(leg1Receipient, leg1TokenAddress, leg1TargetAmount, 0), 
            SwapLeg(leg2Receipient, leg2TokenAddress, leg2TargetAmount, 0)
        );
        emit SwapCreated(newId, leg1Receipient, leg1TokenAddress, leg1TargetAmount, leg2Receipient, leg2TokenAddress, leg2TargetAmount);
    }

    function fundSwapLeg(uint32 id) external {
        
    }

    function cancelSwap(uint32 id) external {

    }

    function getSwapsFor() external {

    }

}
