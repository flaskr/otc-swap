# OTC Swaps

This contains a contract used to facilitate trustless 'over-the-counter' swap of ERC-20 tokens between 2 addresses. This allows 2 addresses to exchange pre-determined token amounts. 

## Workflow
1. Anyone can create an OTC swap, with 2 legs. Each leg has a funder address, a recipient address, token adddress, and a target token amount.
2. Anyone can send tokens to the contract to fund a swap leg on a target swap.
3. Before the swap completes, the swap can be cancelled by one of the 3 parties: swap creator, or either of the leg receipients. This will refund all deposited tokens to the original depositors.
4. Once an OTC swap is completely funded, the contract will dispense the tokens on each leg to each recipient.
