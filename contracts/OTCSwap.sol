//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * Contract for creating over-the-counter ERC20 swap between 2 addresses.
 * Warning - not intended to work with ERC-20 tokens that actually transfer lesser than amount required. Tokens can get stuck during the swap phase when we try to transfer depositedSoFar out from the contract's token balance.
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
                            address leg1Funder,
                            address leg1TokenAddress,
                            uint256 leg1TargetAmount,
                            uint256 leg1DepositSoFar,
                            address leg2Funder,
                            address leg2TokenAddress,
                            uint256 leg2TargetAmount,
                            uint256 leg2DepositSoFar,
                            bool swapExecuted);

    event SwapRefunded(uint32 id,
                        address creator,
                        address leg1Funder,
                        address leg1TokenAddress,
                        uint256 leg1RefundedAmount,
                        address leg2Funder,
                        address leg2TokenAddress,
                        uint256 leg2RefundedAmount);

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
        require(leg1TargetAmount > 0, "Leg 1 amount has to be more than 0.");
        require(leg2TargetAmount > 0, "Leg 2 amount has to be more than 0.");
        require(leg1Funder != leg2Funder, "Swap should be between different accounts.");
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
        require(_swapIdExists(id), "Given swap id does not exist. It might have been cancelled and refunded.");
        Swap storage swapToFund = swapsById[id];
        SwapLeg storage swapLegToFund = _getSwapLeg(swapToFund, msg.sender);
        require(swapLegToFund.tokenAddress == tokenAddress, "Provided token address does not match that of the funding leg of given address for this swap.");
        require(swapLegToFund.depositSoFar < swapLegToFund.targetFundingAmount, "Swap leg is already fully funded.");
        require(swapLegToFund.depositSoFar.add(tokenAmount) <= swapLegToFund.targetFundingAmount.mul(overDepositThreshold), "Total funding amount exceeded deposit threshold. Please verify funding amount."); // Attempt to improve UX by prevent what appears to be very wrong input.
        IERC20 token = IERC20(tokenAddress);
        token.transferFrom(msg.sender, address(this), tokenAmount); //TODO: Should allowance/balance checks be delegated to token contract like this?
        swapLegToFund.depositSoFar.add(tokenAmount); // WARNING: using tokenAmount can be dangerous if the ERC-20 actually transfers lesser than 
        _executeSwapIfFullyFunded(swapToFund);
    }
    
    function _getSwapLeg(Swap storage swapToFund, address funderAddress) internal view returns (SwapLeg storage) {
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
            leg1Token.transfer(swap.leg1.receipientAddress, swap.leg1.depositSoFar); //TODO: Should allowance/balance checks be delegated to token contract like this?
            IERC20 leg2Token = IERC20(swap.leg2.tokenAddress);
            leg2Token.transfer(swap.leg2.receipientAddress, swap.leg2.depositSoFar); //TODO: Should allowance/balance checks be delegated to token contract like this?
            swapExecuted = true;
        }
        emit SwapFundingStatus(swap.id,
                               swap.leg1.funderAddress, 
                               swap.leg1.tokenAddress,
                               swap.leg1.targetFundingAmount,
                               swap.leg1.depositSoFar,
                               swap.leg2.funderAddress, 
                               swap.leg2.tokenAddress,
                               swap.leg2.targetFundingAmount,
                               swap.leg2.depositSoFar,
                               swapExecuted);
    }

    function cancelAndRefundSwap(uint32 id) external {
        require(_swapIdExists(id), "Given swap id does not exist.");
        Swap storage swap = swapsById[id];
        require(_isAddressAPartyInSwap(msg.sender, swap), "Caller is not a creator or funder in this swap.");
        _refundSwapLeg(swap.leg1);
        _refundSwapLeg(swap.leg2);
        emit SwapRefunded(swap.id,
                          swap.creator,
                          swap.leg1.funderAddress,
                          swap.leg1.tokenAddress,
                          swap.leg1.depositSoFar,
                          swap.leg2.funderAddress,
                          swap.leg2.tokenAddress,
                          swap.leg2.depositSoFar);
        delete swapsById[id];
    }

    /**
     * Refunds the swapleg's deposit amount to the funder if there's any balance. 
     * Doesn't set swapLeg.depositSoFar to 0 because we assume the caller is going to delete the stored Swap anyway. The parent is also using it to emit events.
     */
    function _refundSwapLeg(SwapLeg storage swapLeg) internal {
        if (swapLeg.depositSoFar > 0) {
            IERC20 token = IERC20(swapLeg.tokenAddress);
            token.transfer(swapLeg.funderAddress, swapLeg.depositSoFar); //TODO: Can allowance/balance checks be delegated to token contract?
        }
    }

    /**
     * Returns list of swap ids related to given address.
     */
    function getSwapsFor(address targetAddress) external view returns(uint32[] memory) {
        uint numOfSwaps = 0;
        for (uint32 i = 0; i < swapIdCount; i++) {
            if (_swapIdExists(i)) {
                if (_isAddressAPartyInSwap(targetAddress, swapsById[i])) {
                    numOfSwaps++;
                }
            }
        }
        uint32[] memory swapIds = new uint32[](numOfSwaps);
        uint insertIndex = 0;
        for (uint32 i = 0; i < swapIdCount; i++) {
            if (_swapIdExists(i)) {
                if (_isAddressAPartyInSwap(targetAddress, swapsById[i])) {
                    swapIds[insertIndex] = i;
                    insertIndex++;
                }
            }
        }
        return swapIds;
    }

    function _swapIdExists(uint32 id) internal view returns (bool) {
        return abi.encodePacked(swapsById[id].creator).length > 0;
    }

    function _isAddressAPartyInSwap(address addressToCheck, Swap memory swap) public pure returns (bool) {
        return addressToCheck == swap.creator 
                        || addressToCheck == swap.leg1.funderAddress
                        || addressToCheck == swap.leg2.funderAddress;
    }

    function getSwapInfo(uint32 id) external view returns(uint32, address, address, address, uint256, uint256, address, address, uint256, uint256) {
        require(_swapIdExists(id), "No swap found for given id. It may have been refunded.");
        Swap storage swap = swapsById[id];
        return (
            swap.id,
            swap.creator,
            swap.leg1.funderAddress,
            swap.leg1.tokenAddress,
            swap.leg1.targetFundingAmount,
            swap.leg1.depositSoFar,
            swap.leg2.funderAddress,
            swap.leg2.tokenAddress,
            swap.leg2.targetFundingAmount,
            swap.leg2.depositSoFar
        );
    }

}
