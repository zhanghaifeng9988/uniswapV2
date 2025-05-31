// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.0 <0.9.0;

// 从 Uniswap 库移植的 TransferHelper
library TransferHelper {
    /// @notice 安全地转移 ETH 到目标地址，处理可能的错误
    /// @param to 接收 ETH 的地址
    /// @param value 要转移的 ETH 数量
    function safeTransferETH(address to, uint value) internal {
        (bool success,) = to.call{value:value}(new bytes(0));
        require(success, 'TransferHelper: ETH_TRANSFER_FAILED');
    }

    /// @notice 安全地转移代币，处理可能的错误或非标准 ERC20 实现
    /// @param token 代币合约地址
    /// @param to 接收代币的地址
    /// @param value 要转移的代币数量
    function safeTransfer(address token, address to, uint value) internal {
        // 调用 transfer 方法并检查返回值
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FAILED');
    }

    /// @notice 安全地从指定地址转移代币
    /// @param token 代币合约地址
    /// @param from 代币来源地址
    /// @param to 接收代币的地址
    /// @param value 要转移的代币数量
    function safeTransferFrom(address token, address from, address to, uint value) internal {
        // 调用 transferFrom 方法并检查返回值
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FROM_FAILED');
    }

    /// @notice 安全地批准代币使用额度
    /// @param token 代币合约地址
    /// @param spender 被授权的地址
    /// @param value 授权的代币数量
    function safeApprove(address token, address spender, uint value) internal {
        // 调用 approve 方法并检查返回值
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, spender, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: APPROVE_FAILED');
    }
}