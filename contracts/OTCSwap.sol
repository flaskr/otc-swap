//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "hardhat/console.sol";
import './interfaces/IERC20.sol';

/**
 * Contract for creating over-the-counter ERC20 swap between 2 addresses.
 */
contract OTCSwap {
	using SafeMath for uint256;
	
    uint32 private swapIdCount;
    mapping(uint32 => Swap) swapsById;
    /**
     * If the attempt to fund exceed this multiplier of the targetFundingAmount, there most likely was an error, and we will reject the funding attempt.
     */
    uint8 private overDepositThreshold;

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
    
    event SwapFundingStatus(uint32 id,
                      address creator,
                      address leg1Funder,
                      address leg1Receipient,
                      address leg1TokenAddress,
                      uint256 leg1TargetAmount,
                      uint256 leg1DepositSoFar,
                      address leg2Funder,
                      address leg2Receipient,
                      address leg2TokenAddress,
                      uint256 leg2TargetAmount,
                      uint256 leg2DepositSoFar,
                      bool swapExecuted);

    constructor() {
        swapIdCount = 0;
        overDepositThreshold = 2;
    }

    function createNewSwap(address leg1Funder, 
                            address leg1TokenAddress, 
                            uint256 leg1TargetAmount,
                            address leg2Funder, 
                            address leg2TokenAddress, 
                            uint256 leg2TargetAmount) external {
        require(leg1TargetAmount > 0, "Leg 1 amount has to be more than 0.")
        require(leg2TargetAmount > 0, "Leg 2 amount has to be more than 0.")
        require(leg1Funder != leg2Funder, "Swap should be between different accounts.")
        //verify valid token addresses
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

    function fundSwapLeg(uint32 id, address tokenAddress, uint256 tokenAmount) external {
        require(tokenAmount > 0, "Funded amount has to be more than 0.");
        require(swapsById[id], "Given swap id does not exist. It might have been cancelled and refunded.");
        Swap storage swapToFund = swapsById[id];
        SwapLeg storage swapLegToFund = _getSwapLeg(swapToFund, msg.sender);
        require(swapLegToFund.depositSoFar < swapLegToFund.targetFundingAmount, "Swap leg is already fully funded.");
        require(swapLegToFund.depositSoFar.add(tokenAmount) <= swapLegToFund.targetFundingAmount.mul(overDepositThreshold), "Total funding amount exceeded deposit threshold. Please verify funding amount.");
        IERC20 memory token = IERC20(tokenAddress);
        token.transferFrom(msg.sender, address(this), tokenAmount); //TODO: Can allowanance/balance checks be delegated to token contract?
        swapLegToFund.depositSoFar.add(tokenAmount);
        _executeSwapIfFullyFunded(swapToFund);
    }
    
    function _getSwapLeg(Swap storage swapToFund, address funderAddress) internal view returns (SwapLeg) {
        require( funderAddress == swapToFund.leg1.funderAddress || funderAddress == swapToFund.leg2.funderAddress, "Funding address is not from either of the legs.");
        if (funderAddress == swapToFund.leg1.funderAddress) {
            return swapToFund.leg1;
        } else {
            return swapToFund.leg2;
        }
    }
    
    function _executeSwapIfFullyFunded(Swap storage swap) internal {
        bool swapExecuted = false;
        if (swap.leg1.depositSoFar >= swap.leg1.targetFundingAmount &&
            swap.leg2.depositSoFar >= swap.leg2.targetFundingAmount) {
            IERC20 leg1Token = IERC20(swap.leg1.tokenAddress);
            leg1Token.transfer(swap.leg1.receipientAddress, swap.leg1.depositSoFar); //TODO: Can allowanance/balance checks be delegated to token contract?
            IERC20 leg2Token = IERC20(swap.leg2.tokenAddress);
            leg2Token.transfer(swap.leg2.receipientAddress, swap.leg2.depositSoFar); //TODO: Can allowanance/balance checks be delegated to token contract?
            swapExecuted = true;
        }
        emit SwapFundingStatus(swap.id,
                                swap.creator,
                                swap.leg1.funderAddress, 
                                swap.leg1.receipientAddress,
                                swap.leg1.tokenAddress,
                                swap.leg1.targetFundingAmount,
                                swap.leg1.depositSoFar,
                                swap.leg2.funderAddress, 
                                swap.leg2.receipientAddress,
                                swap.leg2.tokenAddress,
                                swap.leg2.targetFundingAmount,
                                swap.leg2.depositSoFar,
                                swapExecuted);
    }
    
    

    function cancelAndRefundSwap(uint32 id) external {
        require(swapsById[id], "Given swap id does not exist.");
        
        
    }

    function getSwapsFor(address targetAddress) external view {
         
    }

}
