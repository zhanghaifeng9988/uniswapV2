const { ethers } = require('ethers');
const { FlashbotsBundleProvider } = require('@flashbots/ethers-provider-bundle');
require('dotenv').config();

// 配置常量
const SEPOLIA_RPC_URL = process.env.SEPOLIA_RPC_URL || 'https://sepolia.infura.io/v3/b2affe5792cd45bd9b462e8762d352f2';
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const NFT_CONTRACT_ADDRESS = process.env.NFT_CONTRACT_ADDRESS; // 部署后填入

// NFT合约ABI（简化版）
const NFT_ABI = [
    "function enablePresale() external",
    "function presale(uint256 amount) external payable",
    "function isPresaleActive() external view returns (bool)",
    "function owner() external view returns (address)",
    "function nextTokenId() external view returns (uint256)"
];

class FlashbotsNFTBundle {
    constructor() {
        this.provider = new ethers.JsonRpcProvider(SEPOLIA_RPC_URL);
        this.wallet = new ethers.Wallet(PRIVATE_KEY, this.provider);
        this.nftContract = new ethers.Contract(NFT_CONTRACT_ADDRESS, NFT_ABI, this.wallet);
    }

    async initFlashbots() {
        // 初始化Flashbots provider
        this.flashbotsProvider = await FlashbotsBundleProvider.create(
            this.provider,
            this.wallet,
            'https://relay-sepolia.flashbots.net',
            'sepolia'
        );
        console.log('✅ Flashbots provider initialized');
    }

    async createBundle(presaleAmount = 1) {
        try {
            console.log('🔄 Creating transaction bundle...');
            
            // 获取当前区块信息
            const block = await this.provider.getBlock('latest');
            const targetBlockNumber = block.number + 1;
            
            // 获取nonce
            const nonce = await this.provider.getTransactionCount(this.wallet.address);
            
            // 估算Gas价格
            const feeData = await this.provider.getFeeData();
            const maxFeePerGas = feeData.maxFeePerGas;
            const maxPriorityFeePerGas = feeData.maxPriorityFeePerGas;
            
            console.log(`📊 Target block: ${targetBlockNumber}`);
            console.log(`📊 Current nonce: ${nonce}`);
            console.log(`📊 Max fee per gas: ${ethers.formatUnits(maxFeePerGas, 'gwei')} gwei`);
            
            // 交易1: enablePresale()
            const enablePresaleTx = {
                to: NFT_CONTRACT_ADDRESS,
                data: this.nftContract.interface.encodeFunctionData('enablePresale'),
                gasLimit: 100000,
                maxFeePerGas: maxFeePerGas,
                maxPriorityFeePerGas: maxPriorityFeePerGas,
                nonce: nonce,
                type: 2,
                chainId: 11155111 // Sepolia
            };
            
            // 交易2: presale(amount)
            const presaleValue = ethers.parseEther((0.01 * presaleAmount).toString());
            const presaleTx = {
                to: NFT_CONTRACT_ADDRESS,
                data: this.nftContract.interface.encodeFunctionData('presale', [presaleAmount]),
                value: presaleValue,
                gasLimit: 150000,
                maxFeePerGas: maxFeePerGas,
                maxPriorityFeePerGas: maxPriorityFeePerGas,
                nonce: nonce + 1,
                type: 2,
                chainId: 11155111
            };
            
            // 签名交易
            const signedTx1 = await this.wallet.signTransaction(enablePresaleTx);
            const signedTx2 = await this.wallet.signTransaction(presaleTx);
            
            console.log('✅ Transactions signed');
            console.log(`💰 Presale amount: ${presaleAmount} NFT(s)`);
            console.log(`💰 Total cost: ${ethers.formatEther(presaleValue)} ETH`);
            
            return {
                signedTransactions: [signedTx1, signedTx2],
                targetBlockNumber
            };
            
        } catch (error) {
            console.error('❌ Error creating bundle:', error);
            throw error;
        }
    }

    async submitBundle(bundle) {
        try {
            console.log('🚀 Submitting bundle to Flashbots...');
            
            const bundleSubmission = await this.flashbotsProvider.sendBundle(
                bundle.signedTransactions,
                bundle.targetBlockNumber
            );
            
            console.log('✅ Bundle submitted successfully');
            console.log('📦 Bundle hash:', bundleSubmission.bundleHash);
            
            return bundleSubmission;
            
        } catch (error) {
            console.error('❌ Error submitting bundle:', error);
            throw error;
        }
    }

    async waitForInclusion(bundleSubmission, maxWaitBlocks = 5) {
        console.log('⏳ Waiting for bundle inclusion...');
        
        for (let i = 0; i < maxWaitBlocks; i++) {
            const blockNumber = bundleSubmission.targetBlockNumber + i;
            // 将区块号转换为十六进制格式
            const hexBlockNumber = '0x' + blockNumber.toString(16);
            
            const bundleStats = await this.flashbotsProvider.getBundleStats(
                bundleSubmission.bundleHash,
                hexBlockNumber
            );
            
            console.log(`📊 Block ${blockNumber} (${hexBlockNumber}) stats:`, bundleStats);
            
            if (bundleStats.isSimulated) {
                console.log('✅ Bundle was simulated successfully');
            }
            
            if (bundleStats.isMined) {
                console.log('🎉 Bundle was mined!');
                return true;
            }
            
            // 等待下一个区块
            await new Promise(resolve => setTimeout(resolve, 12000)); // 12秒
        }
        
        console.log('⚠️ Bundle was not included within the expected timeframe');
        return false;
    }

    async executeFlashbotsPresale(presaleAmount = 1) {
        try {
            console.log('🎯 Starting Flashbots NFT Presale Bundle Execution');
            console.log('=' .repeat(50));
            
            // 初始化Flashbots
            await this.initFlashbots();
            
            // 检查合约状态
            const isActive = await this.nftContract.isPresaleActive();
            const owner = await this.nftContract.owner();
            const nextTokenId = await this.nftContract.nextTokenId();
            
            console.log(`📋 Contract Status:`);
            console.log(`   - Presale Active: ${isActive}`);
            console.log(`   - Owner: ${owner}`);
            console.log(`   - Next Token ID: ${nextTokenId}`);
            console.log(`   - Wallet Address: ${this.wallet.address}`);
            
            if (this.wallet.address.toLowerCase() === owner.toLowerCase()) {
                console.log('⚠️ Warning: You are the contract owner!');
            }
            
            // 创建捆绑交易
            const bundle = await this.createBundle(presaleAmount);
            
            // 提交捆绑
            const submission = await this.submitBundle(bundle);
            
            // 等待执行结果
            const success = await this.waitForInclusion(submission);
            
            if (success) {
                console.log('🎉 Flashbots bundle executed successfully!');
                
                // 验证结果
                const newPresaleStatus = await this.nftContract.isPresaleActive();
                const newNextTokenId = await this.nftContract.nextTokenId();
                
                console.log('📊 Final Status:');
                console.log(`   - Presale Active: ${newPresaleStatus}`);
                console.log(`   - Next Token ID: ${newNextTokenId}`);
                
            } else {
                console.log('❌ Bundle execution failed or timed out');
            }
            
        } catch (error) {
            console.error('💥 Fatal error:', error);
        }
    }
}

// 主执行函数
async function main() {
    if (!NFT_CONTRACT_ADDRESS) {
        console.error('❌ Please set NFT_CONTRACT_ADDRESS in environment variables');
        process.exit(1);
    }
    
    const flashbotsBundle = new FlashbotsNFTBundle();
    
    // 执行Flashbots捆绑交易，购买1个NFT
    await flashbotsBundle.executeFlashbotsPresale(1);
}

// 如果直接运行此脚本
if (require.main === module) {
    main().catch(console.error);
}

module.exports = { FlashbotsNFTBundle };