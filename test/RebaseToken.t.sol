// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test,console} from "forge-std/Test.sol";

import {RebaseToken} from "../src/RebaseToken.sol";
import {Vault} from "../src/Vault.sol";

import {IRebaseToken} from "../src/interfaces/iRebaseToken.sol";

contract RebaseTokenTest is Test {
    RebaseToken private rebaseToken;
    Vault private vault;

    address public owner = makeAddr("owner");
    address public user = makeAddr("user");

    function setUp() public {
        vm.startPrank(owner);
        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grantMintAndBurnRole(address(vault));
        (bool success,) = payable(address(vault)).call{value: 1e18}("");
        vm.stopPrank();
    }

    function testDepositLinear(uint256 amount) public{
        amount = bound(amount,1e5,type(uint96).max);
        vm.startPrank(user);
        vm.deal(user,amount);
        vault.deposit{value:amount}();
        uint256 startBalance = rebaseToken.balanceOf(user);
        console.log("startBalance",startBalance);

        vm.warp(block.timestamp+1 hours);
        uint256 middleBalance = rebaseToken.balanceOf(user);
        assertEq(startBalance,amount);

        vm.warp(block.timestamp + 1 hours);
        assertGt(middleBalance,startBalance);
        uint256 endBalance = rebaseToken.balanceOf(user);

        assertApproxEqAbs(endBalance - middleBalance,middleBalance-startBalance,1);
        vm.stopPrank();
    }

    function testRedeemStraightAway(uint256 amount) public{
        amount  = bound(amount,1e5,type(uint96).max);
        vm.startPrank(user);
        vm.deal(user,amount);
        vault.deposit{value:amount}();
        assertEq(rebaseToken.balanceOf(user),amount);

        vault.redeem(type(uint256).max);
        assertEq(rebaseToken.balanceOf(user),0);
        assertEq(address(user).balance,amount);
        vm.stopPrank();
    }

    function addRewardToVault(uint256 rewardAmount) public{
        (bool success,)  = payable(address(vault)).call{value : rewardAmount}("");
    }

    function testRedeemAfterTimePassed(uint256 depositAmount,uint256 time) public{
        time = bound(time,1000,type(uint96).max);
        depositAmount = bound(depositAmount,1e5,type(uint96).max);

        vm.deal(user,depositAmount);
        vm.prank(user);
        vault.deposit{value:depositAmount}();

        vm.warp(block.timestamp + time);
        uint256 balanceAfterSomeTime = rebaseToken.balanceOf(user);

        vm.deal(owner,balanceAfterSomeTime - depositAmount);
        vm.prank(owner);
        addRewardToVault(balanceAfterSomeTime - depositAmount);

        vm.prank(user);
        vault.redeem(type(uint256).max);

        uint256 ethBalance = address(user).balance;

        assertEq(ethBalance,balanceAfterSomeTime);
        assertGt(ethBalance,depositAmount);
    }

   
}
