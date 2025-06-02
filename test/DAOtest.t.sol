// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/DAO/token/VotingToken.sol";
import "../src/DAO/tokenBank/TokenBank.sol";
import "../src/DAO/governance/DAOGovernor.sol";

contract DAOTest is Test {
    VotingToken public token;
    TokenBank public tokenBank;
    DAOGovernor public governor;
    
    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    
    uint256 public constant INITIAL_SUPPLY = 1000000 * 10**18;
    uint48 public constant VOTING_DELAY = 1; // 修改为uint48
    uint32 public constant VOTING_PERIOD = 50400; // 修改为uint32
    uint256 public constant PROPOSAL_THRESHOLD = 1000 * 10**18;
    uint256 public constant QUORUM_PERCENTAGE = 4;
    
    function setUp() public {
        vm.startPrank(owner);
        
        // 部署VotingToken
        token = new VotingToken(
            "DAO Token",
            "DAO",
            INITIAL_SUPPLY,
            owner
        );
        
        // 部署Governor
        governor = new DAOGovernor(
            IVotes(address(token)),
            VOTING_DELAY,
            VOTING_PERIOD,
            PROPOSAL_THRESHOLD,
            QUORUM_PERCENTAGE
        );
        
        // 部署TokenBank，设置Governor为管理员
        tokenBank = new TokenBank(address(governor));
        
        // 分发代币给用户
        token.transfer(user1, 100000 * 10**18);
        token.transfer(user2, 50000 * 10**18);
        
        // *** 修复：使用depositToken而不是直接transfer ***
        token.approve(address(tokenBank), 50000 * 10**18);
        tokenBank.depositToken(address(token), 50000 * 10**18);
        
        vm.stopPrank();
        
        // 用户委托投票权给自己
        vm.prank(user1);
        token.delegate(user1);
        
        vm.prank(user2);
        token.delegate(user2);
        
        // 推进区块以确保投票权生效
        vm.roll(block.number + 1);
        
        // 向TokenBank存入一些ETH
        vm.deal(address(tokenBank), 10 ether);
    }
    
    function testTokenBasicFunctionality() public {
        assertEq(token.name(), "DAO Token");
        assertEq(token.symbol(), "DAO");
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.balanceOf(user1), 100000 * 10**18);
    }
    
    function testTokenBankDeposit() public {
        uint256 initialBalance = tokenBank.getEthBalance();
        
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        tokenBank.depositEth{value: 1 ether}();
        
        assertEq(tokenBank.getEthBalance(), initialBalance + 1 ether);
    }
    
    function testTokenDeposit() public {
        uint256 depositAmount = 1000 * 10**18;
        
        // *** 修复：获取初始余额 ***
        uint256 initialTokenBalance = tokenBank.getTokenBalance(address(token));
        
        vm.startPrank(user1);
        token.approve(address(tokenBank), depositAmount);
        tokenBank.depositToken(address(token), depositAmount);
        vm.stopPrank();
        
        // *** 修复：使用正确的期望值 ***
        assertEq(tokenBank.getTokenBalance(address(token)), initialTokenBalance + depositAmount);
    }
    
    function testGovernorProposal() public {
        // *** 修复：确保有足够的区块间隔 ***
        vm.roll(block.number + 1);
        
        // 创建提案：从TokenBank提取1 ether到user1
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        
        targets[0] = address(tokenBank);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature(
            "withdrawEth(address,uint256)",
            payable(user1),
            1 ether
        );
        
        vm.prank(user1);
        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            "Withdraw 1 ETH to user1"
        );
        
        // 检查提案状态
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Pending));
        
        // 等待投票延迟
        vm.roll(block.number + VOTING_DELAY + 1);
        
        // 检查提案现在是活跃状态
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Active));
        
        // 投票支持
        vm.prank(user1);
        governor.castVote(proposalId, 1); // 1 = For
        
        vm.prank(user2);
        governor.castVote(proposalId, 1); // 1 = For
        
        // 等待投票期结束
        vm.roll(block.number + VOTING_PERIOD + 1);
        
        // 检查提案成功
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Succeeded));
        
        // 执行提案
        uint256 user1BalanceBefore = user1.balance;
        governor.execute(targets, values, calldatas, keccak256(bytes("Withdraw 1 ETH to user1")));
        
        // 验证提案执行成功
        assertEq(user1.balance, user1BalanceBefore + 1 ether);
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Executed));
    }
    
    function testGovernorTokenWithdrawal() public {
        // *** 修复：确保有足够的区块间隔 ***
        vm.roll(block.number + 1);
        
        // 创建提案：从TokenBank提取代币到user1
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        
        targets[0] = address(tokenBank);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature(
            "withdrawToken(address,address,uint256)",
            address(token),
            user1,
            1000 * 10**18
        );
        
        vm.prank(user1);
        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            "Withdraw 1000 DAO tokens to user1"
        );
        
        // 等待投票延迟
        vm.roll(block.number + VOTING_DELAY + 1);
        
        // 投票支持
        vm.prank(user1);
        governor.castVote(proposalId, 1);
        
        vm.prank(user2);
        governor.castVote(proposalId, 1);
        
        // 等待投票期结束
        vm.roll(block.number + VOTING_PERIOD + 1);
        
        // 执行提案
        uint256 user1TokenBalanceBefore = token.balanceOf(user1);
        governor.execute(targets, values, calldatas, keccak256(bytes("Withdraw 1000 DAO tokens to user1")));
        
        // 验证提案执行成功
        assertEq(token.balanceOf(user1), user1TokenBalanceBefore + 1000 * 10**18);
    }
    
    function testUnauthorizedTokenBankWithdrawal() public {
        vm.prank(user1);
        vm.expectRevert();
        tokenBank.withdrawEth(payable(user1), 1 ether);
    }
}