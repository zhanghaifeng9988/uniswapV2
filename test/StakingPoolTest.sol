// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/Pledge-based_mining_loaning/StakingPool.sol";
import "../src/Pledge-based_mining_loaning/KKToken.sol";

contract StakingPoolTest is Test {
    StakingPool public stakingPool;
    KKToken public kkToken;
    
    address public alice = address(0x1);
    address public bob = address(0x2);
    
    function setUp() public {
        // 部署KK Token
        kkToken = new KKToken();
        
        // 部署质押池
        stakingPool = new StakingPool(address(kkToken));
        
        // 设置质押池为KK Token的铸造者
        kkToken.addMinter(address(stakingPool));
        
        // 给测试账户一些ETH
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
    }
    
    function testStake() public {
        vm.startPrank(alice);
        
        // Alice质押1 ETH
        stakingPool.stake{value: 1 ether}();
        
        // 检查质押余额
        assertEq(stakingPool.balanceOf(alice), 1 ether);
        
        vm.stopPrank();
    }
    
    function testEarnRewards() public {
        vm.startPrank(alice);
        
        // Alice质押1 ETH
        stakingPool.stake{value: 1 ether}();
        
        vm.stopPrank();
        
        // 模拟挖矿10个区块
        vm.roll(block.number + 10);
        
        // 检查Alice的待领取奖励
        uint256 earned = stakingPool.earned(alice);
        assertEq(earned, 10 * 10 * 1e18); // 10个区块 * 每区块10个KK
    }
    
    function testClaim() public {
        vm.startPrank(alice);
        
        // Alice质押1 ETH
        stakingPool.stake{value: 1 ether}();
        
        vm.stopPrank();
        
        // 模拟挖矿5个区块
        vm.roll(block.number + 5);
        
        vm.startPrank(alice);
        
        // Alice领取奖励
        uint256 balanceBefore = kkToken.balanceOf(alice);
        stakingPool.claim();
        uint256 balanceAfter = kkToken.balanceOf(alice);
        
        // 检查KK token余额增加
        assertEq(balanceAfter - balanceBefore, 5 * 10 * 1e18);
        
        vm.stopPrank();
    }
    
    function testUnstake() public {
        vm.startPrank(alice);
        
        // Alice质押2 ETH
        stakingPool.stake{value: 2 ether}();
        
        // 模拟挖矿3个区块
        vm.roll(block.number + 3);
        
        // Alice赎回1 ETH
        uint256 ethBalanceBefore = alice.balance;
        uint256 kkBalanceBefore = kkToken.balanceOf(alice);
        
        stakingPool.unstake(1 ether);
        
        // 检查ETH余额
        assertEq(alice.balance - ethBalanceBefore, 1 ether);
        
        // 检查质押余额
        assertEq(stakingPool.balanceOf(alice), 1 ether);
        
        // 检查获得的KK token奖励
        assertEq(kkToken.balanceOf(alice) - kkBalanceBefore, 3 * 10 * 1e18);
        
        vm.stopPrank();
    }
    
    function testMultipleUsers() public {
        // Alice stakes 1 ETH at block 1
        vm.prank(alice);
        stakingPool.stake{value: 1 ether}();
        
        // Mine 2 blocks (to block 3)
        vm.roll(3);
        
        // Bob stakes 1 ETH at block 3
        vm.prank(bob);
        stakingPool.stake{value: 1 ether}();
        
        // Mine 2 more blocks (to block 5)
        vm.roll(5);
        
        // Check rewards
        // Alice: 2 blocks alone (20 KK) + 2 blocks shared 50% (10 KK) = 30 KK total
        assertEq(stakingPool.earned(alice), 30 ether);
        // Bob: 2 blocks shared 50% (10 KK) = 10 KK total
        assertEq(stakingPool.earned(bob), 10 ether);
    }
    
    function testMultipleUsersDetailed() public {
        // 更详细的多用户测试
        console.log("=== Start detailed multi-user test ===");
        
        uint256 startBlock = block.number;
        console.log("Start block:", startBlock);
        
        // Alice质押1 ETH
        vm.prank(alice);
        stakingPool.stake{value: 1 ether}();
        console.log("Block after Alice stakes:", block.number);
        
        // 挖矿2个区块
        vm.roll(block.number + 2);
        console.log("Block after mining 2 blocks:", block.number);
        console.log("Alice pending rewards:", stakingPool.earned(alice) / 1e18);
        
        // Bob质押1 ETH
        vm.prank(bob);
        stakingPool.stake{value: 1 ether}();
        console.log("Block after Bob stakes:", block.number);
        console.log("Alice pending rewards:", stakingPool.earned(alice) / 1e18);
        console.log("Bob pending rewards:", stakingPool.earned(bob) / 1e18);
        
        // 再挖矿2个区块
        vm.roll(block.number + 2);
        console.log("Block after mining 2 more blocks:", block.number);
        console.log("Alice pending rewards:", stakingPool.earned(alice) / 1e18);
        console.log("Bob pending rewards:", stakingPool.earned(bob) / 1e18);
    }
}