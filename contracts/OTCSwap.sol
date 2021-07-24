//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "hardhat/console.sol";

/**
 * Contract for creating over-the-counter ERC20 swap between 2 addresses.
 */
contract OTCSwap {

    // For handling ERC20, check https://ethereum.org/en/developers/tutorials/transfers-and-approval-of-erc-20-tokens-from-a-solidity-smart-contract/

    uint32 swapIdCount;
    mapping(uint32 => Swap) swapsById;

    /**
     * Holds the state for a swap between 2 receipients.
     */
    struct Swap {
        uint32 id;
        address creator;
        SwapLeg leg1;
        SwapLeg leg2;
    }

    /**
     * Represents one leg of a swap.
     */
    struct SwapLeg {
        address funderAddress;
        address receipientAddress;
        address tokenAddress;
        uint256 targetFundingAmount;
        uint256 depositSoFar;
    }

    event SwapCreated(uint32 id,
                      address creator,
                      address leg1Funder,
                      address leg1Receipient,
                      address leg1TokenAddress,
                      uint256 leg1TargetAmount,
                      address leg2Funder,
                      address leg2Receipient,
                      address leg2TokenAddress,
                      uint256 leg2TargetAmount);
    

    constructor() {
        swapIdCount = 0;
    }

    function createNewSwap(address leg1Funder, 
                            address leg1TokenAddress, 
                            uint256 leg1TargetAmount,
                            address leg2Funder, 
                            address leg2TokenAddress, 
                            uint256 leg2TargetAmount) external {
        swapIdCount++;
        uint32 newId = swapIdCount;
        SwapLeg memory leg1 = SwapLeg(leg1Funder, leg2Funder, leg1TokenAddress, leg1TargetAmount, 0);
        SwapLeg memory leg2 = SwapLeg(leg2Funder, leg1Funder, leg2TokenAddress, leg2TargetAmount, 0);
        swapsById[newId] = Swap(
            newId, 
            msg.sender,
            leg1, 
            leg2
        );
        emit SwapCreated(
            newId, 
            msg.sender,
            leg1.funderAddress, 
            leg1.receipientAddress,
            leg1.tokenAddress,
            leg1.targetFundingAmount,
            leg2.funderAddress, 
            leg2.receipientAddress,
            leg2.tokenAddress,
            leg2.targetFundingAmount
        );
    }

    function fundSwapLeg(uint32 id) external {
        
    }

    function cancelSwap(uint32 id) external {
        
    }

    function getSwapsFor(address targetAddress) external view {
         
    }

}
