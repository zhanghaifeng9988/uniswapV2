const { ethers } = require('ethers');
const { FlashbotsBundleProvider } = require('@flashbots/ethers-provider-bundle');
const fs = require('fs');
const readline = require('readline');
require('dotenv').config();

// 配置常量
const SEPOLIA_RPC_URL = process.env.SEPOLIA_RPC_URL || 'https://sepolia.infura.io/v3/b2affe5792cd45bd9b462e8762d352f2';
const KEYSTORE_PATH = '.keys/fox1'; // 修改为新的keystore文件
const NFT_CONTRACT_ADDRESS = process.env.NFT_CONTRACT_ADDRESS;

// NFT合约ABI
const NFT_ABI = [
    "function enablePresale() external",
    "function presale(uint256 amount) external payable",
    "function isPresaleActive() external view returns (bool)",
    "function owner() external view returns (address)",
    "function nextTokenId() external view returns (uint256)"
];

// 读取keystore密码的函数
function getPassword() {
    return new Promise((resolve) => {
        const rl = readline.createInterface({
            input: process.stdin,
            output: process.stdout
        });
        
        rl.question('请输入keystore密码: ', (password) => {
            rl.close();
            resolve(password);
        });
    });
}

class FlashbotsNFTBundleKeystore {
    constructor() {
        this.provider = new ethers.JsonRpcProvider(SEPOLIA_RPC_URL);
    }

    async initWallet() {
        try {
            // 读取keystore文件
            const keystoreJson = fs.readFileSync(KEYSTORE_PATH, 'utf8');
            
            // 获取密码
            const password = await getPassword();
            
            // 解密keystore
            this.wallet = await ethers.Wallet.fromEncryptedJson(keystoreJson, password);
            this.wallet = this.wallet.connect(this.provider);
            
            this.nftContract = new ethers.Contract(NFT_CONTRACT_ADDRESS, NFT_ABI, this.wallet);
            
            console.log('✅ Keystore解密成功');
            console.log('📍 钱包地址:', this.wallet.address);
            
        } catch (error) {
            console.error('❌ Keystore解密失败:', error.message);
            throw error;
        }
    }

    async initFlashbots() {
        this.flashbotsProvider = await FlashbotsBundleProvider.create(
            this.provider,
            this.wallet,
            'https://relay-sepolia.flashbots.net',
            'sepolia'
        );
        console.log('✅ Flashbots提供者初始化完成');
    }

    async createBundle(presaleAmount = 1) {
        try {
            console.log('🔄 创建交易捆绑包...');
            
            const block = await this.provider.getBlock('latest');
            const targetBlockNumber = block.number + 1;
            const nonce = await this.provider.getTransactionCount(this.wallet.address);
            const feeData = await this.provider.getFeeData();
            // 提高 Gas 费用 10 倍以增加竞争力 - 直接在wei单位上计算避免精度问题
            const maxFeePerGas = feeData.maxFeePerGas * 10n;
            const maxPriorityFeePerGas = feeData.maxPriorityFeePerGas * 10n;
            
            console.log(`📊 目标区块: ${targetBlockNumber}`);
            console.log(`📊 当前nonce: ${nonce}`);
            console.log(`📊 最大gas费用: ${ethers.formatUnits(maxFeePerGas, 'gwei')} gwei (提高10倍)`);
            console.log(`📊 优先费用: ${ethers.formatUnits(maxPriorityFeePerGas, 'gwei')} gwei (提高10倍)`);
            
            const enablePresaleTx = {
                to: NFT_CONTRACT_ADDRESS,
                data: this.nftContract.interface.encodeFunctionData('enablePresale'),
                gasLimit: 100000,
                maxFeePerGas: maxFeePerGas,
                maxPriorityFeePerGas: maxPriorityFeePerGas,
                nonce: nonce,
                type: 2,
                chainId: 11155111
            };
            
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
            
            const signedTx1 = await this.wallet.signTransaction(enablePresaleTx);
            const signedTx2 = await this.wallet.signTransaction(presaleTx);
            
            console.log('✅ 交易签名完成');
            console.log(`💰 预售数量: ${presaleAmount} 个NFT`);
            console.log(`💰 总费用: ${ethers.formatEther(presaleValue)} ETH`);
            
            return {
                signedTransactions: [signedTx1, signedTx2],
                targetBlockNumber
            };
            
        } catch (error) {
            console.error('❌ 创建捆绑包时出错:', error);
            throw error;
        }
    }

    async submitBundle(bundle) {
        try {
            console.log('🚀 向Flashbots提交捆绑包...');
            
            // 将签名的交易字符串转换为交易对象格式
            const transactions = bundle.signedTransactions.map(signedTx => ({
                signedTransaction: signedTx
            }));
            
            const bundleSubmission = await this.flashbotsProvider.sendBundle(
                transactions,
                bundle.targetBlockNumber
            );
            
            console.log('✅ 捆绑包提交成功');
            console.log('📦 捆绑包哈希:', bundleSubmission.bundleHash);
            
            // 确保返回的对象包含 targetBlockNumber
            return {
                ...bundleSubmission,
                targetBlockNumber: bundle.targetBlockNumber
            };
            
        } catch (error) {
            console.error('❌ 提交捆绑包时出错:', error);
            throw error;
        }
    }

    async waitForInclusion(bundleSubmission, maxWaitBlocks = 5) {
        console.log('⏳ 等待捆绑包被包含...');
        
        for (let i = 0; i < maxWaitBlocks; i++) {
            const blockNumber = bundleSubmission.targetBlockNumber + i;
            
            try {
                // 使用 getBundleStatsV2 替代 getBundleStats
                const bundleStats = await this.flashbotsProvider.getBundleStatsV2(
                    bundleSubmission.bundleHash,
                    blockNumber
                );
                
                console.log(`📊 区块 ${blockNumber} 统计:`, bundleStats);
                
                if (bundleStats.isSimulated) {
                    console.log('✅ 捆绑包模拟成功');
                }
                
                if (bundleStats.isMined) {
                    console.log('🎉 捆绑包已被挖矿!');
                    return true;
                }
            } catch (error) {
                console.log(`⚠️ 获取区块 ${blockNumber} 统计时出错:`, error.message);
            }
            
            // 等待下一个区块
            await new Promise(resolve => setTimeout(resolve, 12000)); // 12秒
        }
        
        console.log('⚠️ 捆绑包在预期时间内未被包含');
        return false;
    }

    async executeFlashbotsPresale(presaleAmount = 1) {
        try {
            console.log('🎯 开始执行Flashbots NFT预售捆绑包');
            console.log('='.repeat(50));
            
            // 初始化钱包
            await this.initWallet();
            
            // 初始化Flashbots
            await this.initFlashbots();
            
            // 检查合约状态
            const isActive = await this.nftContract.isPresaleActive();
            const owner = await this.nftContract.owner();
            const nextTokenId = await this.nftContract.nextTokenId();
            
            console.log(`📋 合约状态:`);
            console.log(`   - 预售激活: ${isActive}`);
            console.log(`   - 所有者: ${owner}`);
            console.log(`   - 下一个Token ID: ${nextTokenId}`);
            console.log(`   - 钱包地址: ${this.wallet.address}`);
            
            if (this.wallet.address.toLowerCase() === owner.toLowerCase()) {
                console.log('⚠️ 警告: 你是合约所有者!');
            }
            
            // 创建并提交捆绑包
            const bundle = await this.createBundle(presaleAmount);
            const submission = await this.submitBundle(bundle);
            const success = await this.waitForInclusion(submission);
            
            if (success) {
                console.log('🎉 Flashbots捆绑包执行成功!');
                
                // 验证结果
                const newPresaleStatus = await this.nftContract.isPresaleActive();
                const newNextTokenId = await this.nftContract.nextTokenId();
                
                console.log('📊 最终状态:');
                console.log(`   - 预售激活: ${newPresaleStatus}`);
                console.log(`   - 下一个Token ID: ${newNextTokenId}`);
                
            } else {
                console.log('❌ 捆绑包执行失败或超时');
            }
            
        } catch (error) {
            console.error('💥 致命错误:', error);
        }
    }
}

// 主执行函数
async function main() {
    if (!NFT_CONTRACT_ADDRESS) {
        console.error('❌ 请在环境变量中设置NFT_CONTRACT_ADDRESS');
        process.exit(1);
    }
    
    const flashbotsBundle = new FlashbotsNFTBundleKeystore();
    
    // 执行Flashbots捆绑交易，购买1个NFT
    await flashbotsBundle.executeFlashbotsPresale(1);
}

// 如果直接运行此脚本
if (require.main === module) {
    main().catch(console.error);
}

module.exports = { FlashbotsNFTBundleKeystore };


// 改为
const CONTRACT_ADDRESS = '0xacbd47221c865EC595Ff2604e92a9140d9637b77';