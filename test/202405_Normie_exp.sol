// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console2} from "forge-std/Test.sol";

/**
 * Incident Write-up: https://www.certik.com/resources/blog/normie-incident-analysis
 * Chain: Base
 * Attack Tx : https://app.blocksec.com/explorer/tx/base/0xa618933a0e0ffd0b9f4f0835cc94e523d0941032821692c01aa96cd6f80fc3fd

 */
contract NormieExploit is Test {
    address SushiRouterv2 = 0x6BDED42c6DA8FBf0d2bA55B2fa120C5e0c8D7891;
    
    address SLP = 0x24605E0bb933f6EC96E6bBbCEa0be8cC880F6E6f;

    address UniswapV3Pool = 0x67ab0E84C7f9e399a67037F94a08e5C664DC1C66;

    address WETH = 0x4200000000000000000000000000000000000006;

    address NORMIE = 0x7F12d13B34F5F4f0a9449c16Bcd42f0da47AF200;

    function setUp() public {
        vm.createSelectFork("https://base.llamarpc.com", 14952783 - 1);
    }

    function testExploit() public {

    }
}
