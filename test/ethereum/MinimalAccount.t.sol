// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {console2, Script} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {DeployMinimal} from "../../script/DeployMinimal.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {MinimalAccount} from "../../src/ethereum/MinimalAccount.sol";

contract MinimalAccountTest is Test {
    DeployMinimal deployMinimal;
    HelperConfig helperConfig;
    MinimalAccount minimalAccount;
    ERC20Mock usdc;

    uint256 constant AMOUNT = 1e18;

    address notOwner = makeAddr("notOwner");

    function setUp() public {
        deployMinimal = new DeployMinimal();
        (helperConfig, minimalAccount) = deployMinimal.deployMinimalAccount();
        usdc = new ERC20Mock();
    }

    function testOwnerCanExecuteCommands() public {
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT); // gets function selector

        vm.prank(minimalAccount.owner());
        minimalAccount.execute(dest, value, functionData);
        vm.stopPrank();

        assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT);
    }

    function testNonOwnerCannotExecuteCommands() public {
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

        vm.prank(notOwner);
        vm.expectRevert(MinimalAccount.MinimalAccount__NotFromEntryPointOrOwner.selector);
        minimalAccount.execute(dest, value, functionData);
        vm.stopPrank();
    }
}
