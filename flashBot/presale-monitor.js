const { ethers } = require('ethers');
require('dotenv').config();

const SEPOLIA_RPC_URL = process.env.SEPOLIA_RPC_URL || 'https://sepolia.infura.io/v3/b2affe5792cd45bd9b462e8762d352f2';
const NFT_CONTRACT_ADDRESS = process.env.NFT_CONTRACT_ADDRESS;

const NFT_ABI = [
    "function isPresaleActive() external view returns (bool)",
    "function presale(uint256 amount) external payable",
    "event PresaleStatusChanged(bool status)"
];

class PresaleMonitor {
    constructor() {
        this.provider = new ethers.JsonRpcProvider(SEPOLIA_RPC_URL);
        this.contract = new ethers.Contract(NFT_CONTRACT_ADDRESS, NFT_ABI, this.provider);
        this.isMonitoring = false;
    }

    // 方法1: 事件监听（推荐）
    async startEventListener() {
        console.log('🔍 Starting presale status event listener...');
        
        // 监听 PresaleStatusChanged 事件
        this.contract.on('PresaleStatusChanged', (status, event) => {
            console.log(`\n🚨 预售状态变更通知!`);
            console.log(`📅 时间: ${new Date().toLocaleString()}`);
            console.log(`📊 预售状态: ${status ? '已开启' : '已关闭'}`);
            console.log(`🔗 交易哈希: ${event.transactionHash}`);
            console.log(`📦 区块号: ${event.blockNumber}`);
            
            if (status) {
                console.log('\n🎯 预售已开启！现在可以参与预售了！');
                console.log('💡 执行命令: node execute.js [数量] [矿工费用]');
                // 这里可以自动触发预售购买逻辑
                this.triggerAutoBuy();
            }
        });
        
        console.log('✅ 事件监听器已启动，等待预售状态变更...');
    }

    // 方法2: 轮询检查
    async startPolling(intervalMs = 5000) {
        console.log(`🔄 Starting presale status polling (every ${intervalMs}ms)...`);
        this.isMonitoring = true;
        
        let lastStatus = await this.contract.isPresaleActive();
        console.log(`📊 当前预售状态: ${lastStatus ? '已开启' : '已关闭'}`);
        
        const pollInterval = setInterval(async () => {
            try {
                const currentStatus = await this.contract.isPresaleActive();
                
                if (currentStatus !== lastStatus) {
                    console.log(`\n🚨 预售状态变更!`);
                    console.log(`📅 时间: ${new Date().toLocaleString()}`);
                    console.log(`📊 新状态: ${currentStatus ? '已开启' : '已关闭'}`);
                    
                    if (currentStatus) {
                        console.log('\n🎯 预售已开启！现在可以参与预售了！');
                        // 自动触发购买
                        this.triggerAutoBuy();
                    }
                    
                    lastStatus = currentStatus;
                }
            } catch (error) {
                console.error('❌ 轮询检查出错:', error.message);
            }
        }, intervalMs);
        
        // 优雅退出处理
        process.on('SIGINT', () => {
            console.log('\n🛑 停止监听...');
            clearInterval(pollInterval);
            process.exit(0);
        });
    }

    // 自动购买触发器
    async triggerAutoBuy() {
        console.log('🤖 触发自动购买逻辑...');
        
        // 这里可以调用 FlashbotsNFTBundle 或直接执行预售
        // 示例：
        try {
            const { FlashbotsNFTBundle } = require('./flashbots-bundle');
            const bundle = new FlashbotsNFTBundle();
            await bundle.executeFlashbotsPresale(1, "0.002"); // 购买1个NFT，矿工费用0.002 ETH
        } catch (error) {
            console.error('❌ 自动购买失败:', error.message);
        }
    }

    // 手动检查当前状态
    async checkCurrentStatus() {
        try {
            const isActive = await this.contract.isPresaleActive();
            const blockNumber = await this.provider.getBlockNumber();
            
            console.log('📊 当前预售状态检查:');
            console.log(`   - 预售状态: ${isActive ? '已开启' : '已关闭'}`);
            console.log(`   - 当前区块: ${blockNumber}`);
            console.log(`   - 检查时间: ${new Date().toLocaleString()}`);
            
            return isActive;
        } catch (error) {
            console.error('❌ 状态检查失败:', error.message);
            return false;
        }
    }
}

// 主函数
async function main() {
    if (!NFT_CONTRACT_ADDRESS) {
        console.error('❌ 请在环境变量中设置 NFT_CONTRACT_ADDRESS');
        process.exit(1);
    }
    
    const monitor = new PresaleMonitor();
    
    // 首先检查当前状态
    await monitor.checkCurrentStatus();
    
    // 选择监听方式
    const method = process.argv[2] || 'event';
    
    if (method === 'event') {
        // 使用事件监听（推荐）
        await monitor.startEventListener();
    } else if (method === 'poll') {
        // 使用轮询方式
        const interval = parseInt(process.argv[3]) || 5000;
        await monitor.startPolling(interval);
    } else {
        console.log('❌ 无效的监听方式。使用: node presale-monitor.js [event|poll] [interval]');
        process.exit(1);
    }
}

if (require.main === module) {
    main().catch(console.error);
}

module.exports = { PresaleMonitor };