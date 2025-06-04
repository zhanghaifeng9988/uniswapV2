const { ethers } = require('ethers');
const { FlashbotsBundleProvider } = require('@flashbots/ethers-provider-bundle');
const fs = require('fs');
const path = require('path');
const readline = require('readline');
require('dotenv').config();

// 配置常量
const SEPOLIA_RPC_URL = process.env.SEPOLIA_RPC_URL || 'https://sepolia.infura.io/v3/b2affe5792cd45bd9b462e8762d352f2';
const NFT_CONTRACT_ADDRESS = process.env.NFT_CONTRACT_ADDRESS;
const KEYS_DIR = path.join(__dirname, '.keys');

// NFT合约ABI
const NFT_ABI = [
    "function enablePresale() external",
    "function presale(uint256 amount) external payable",
    "function isPresaleActive() external view returns (bool)",
    "function owner() external view returns (address)",
    "function nextTokenId() external view returns (uint256)"
];

class FlashbotsNFTBundleMultiUser {
    constructor() {
        this.provider = new ethers.JsonRpcProvider(SEPOLIA_RPC_URL);
        this.wallets = [];
        this.nftContract = null;
        this.password = null;
    }

    // 从命令行输入密码
    async promptPassword() {
        const rl = readline.createInterface({
            input: process.stdin,
            output: process.stdout
        });

        return new Promise((resolve) => {
            rl.question('请输入 keystore 解密密码: ', (password) => {
                rl.close();
                resolve(password);
            });
        });
    }

    // 加载密码（优先使用命令行输入，其次使用文件）
    async loadPassword() {
        try {
            // 首先尝试从命令行输入
            console.log('🔐 需要输入 keystore 解密密码');
            this.password = await this.promptPassword();
            console.log('✅ 密码输入完成');
        } catch (error) {
            // 如果输入失败，尝试从文件读取
            try {
                const passwordPath = path.join(KEYS_DIR, 'password');
                this.password = fs.readFileSync(passwordPath, 'utf8').trim();
                console.log('✅ 从文件加载密码');
            } catch (fileError) {
                console.error('❌ 无法获取密码:', error.message);
                throw error;
            }
        }
    }

    // 从 keystore 文件创建钱包
    async loadWalletFromKeystore(filename) {
        try {
            const keystorePath = path.join(KEYS_DIR, filename);
            const keystoreJson = fs.readFileSync(keystorePath, 'utf8').trim();
            
            console.log(`🔓 正在解密 keystore 文件: ${filename}`);
            
            // 使用密码解密 keystore
            const wallet = await ethers.Wallet.fromEncryptedJson(keystoreJson, this.password);
            const connectedWallet = wallet.connect(this.provider);
            
            console.log(`✅ 成功解密钱包: ${filename} -> ${connectedWallet.address}`);
            return connectedWallet;
        } catch (error) {
            console.error(`❌ 解密 keystore 文件失败 ${filename}:`, error.message);
            throw error;
        }
    }

    // 初始化钱包
    async initWallets(keyFiles) {
        console.log('🔑 正在初始化钱包...');
        
        // 首先加载密码
        await this.loadPassword();
        
        for (const keyFile of keyFiles) {
            const wallet = await this.loadWalletFromKeystore(keyFile);
            this.wallets.push({
                wallet,
                keyFile,
                address: wallet.address
            });
            console.log(`📝 钱包 ${keyFile}: ${wallet.address}`);
        }
        
        // 使用第一个钱包作为主钱包（用于合约交互）
        this.mainWallet = this.wallets[0].wallet;
        this.nftContract = new ethers.Contract(NFT_CONTRACT_ADDRESS, NFT_ABI, this.mainWallet);
        
        console.log(`✅ 初始化了 ${this.wallets.length} 个钱包`);
    }

    async initFlashbots() {
        this.flashbotsProvider = await FlashbotsBundleProvider.create(
            this.provider,
            this.mainWallet,
            'https://relay-sepolia.flashbots.net',
            'sepolia'
        );
        console.log('✅ Flashbots provider 初始化完成');
    }

    async createMultiUserBundle(presaleAmounts, minerTip = "0.001") {
        try {
            console.log('🔄 创建多用户交易捆绑包...');
            
            const block = await this.provider.getBlock('latest');
            const targetBlockNumber = block.number + 1;
            
            const feeData = await this.provider.getFeeData();
            const maxFeePerGas = feeData.maxFeePerGas;
            const maxPriorityFeePerGas = feeData.maxPriorityFeePerGas || ethers.parseUnits('2', 'gwei');
            
            console.log(`📊 目标区块: ${targetBlockNumber}`);
            console.log(`📊 最大Gas费用: ${ethers.formatUnits(maxFeePerGas, 'gwei')} gwei`);
            
            const signedTransactions = [];
            let currentNonce = await this.provider.getTransactionCount(this.mainWallet.address);
            
            // 交易1: enablePresale()
            const enablePresaleTx = {
                to: NFT_CONTRACT_ADDRESS,
                data: this.nftContract.interface.encodeFunctionData('enablePresale'),
                gasLimit: 100000,
                maxFeePerGas: maxFeePerGas,
                maxPriorityFeePerGas: maxPriorityFeePerGas,
                nonce: currentNonce++,
                type: 2,
                chainId: 11155111
            };
            
            const signedEnableTx = await this.mainWallet.signTransaction(enablePresaleTx);
            signedTransactions.push(signedEnableTx);
            
            // 为每个钱包创建预售交易
            for (let i = 0; i < this.wallets.length && i < presaleAmounts.length; i++) {
                const walletInfo = this.wallets[i];
                const amount = presaleAmounts[i];
                
                if (amount <= 0) continue;
                
                const walletNonce = await this.provider.getTransactionCount(walletInfo.address);
                
                const presaleValue = ethers.parseEther((0.01 * amount).toString());
                const presaleTx = {
                    to: NFT_CONTRACT_ADDRESS,
                    data: this.nftContract.interface.encodeFunctionData('presale', [amount]),
                    value: presaleValue,
                    gasLimit: 150000,
                    maxFeePerGas: maxFeePerGas,
                    maxPriorityFeePerGas: maxPriorityFeePerGas,
                    nonce: walletNonce,
                    type: 2,
                    chainId: 11155111
                };
                
                const signedPresaleTx = await walletInfo.wallet.signTransaction(presaleTx);
                signedTransactions.push(signedPresaleTx);
                
                console.log(`💰 钱包 ${walletInfo.keyFile} (${walletInfo.address}): ${amount} NFT(s), 费用: ${ethers.formatEther(presaleValue)} ETH`);
            }
            
            // 矿工激励交易
            const minerTipValue = ethers.parseEther(minerTip);
            const minerTipTx = {
                to: "0x0000000000000000000000000000000000000000",
                value: minerTipValue,
                gasLimit: 21000,
                maxFeePerGas: maxFeePerGas,
                maxPriorityFeePerGas: maxPriorityFeePerGas,
                nonce: currentNonce,
                type: 2,
                chainId: 11155111
            };
            
            const signedMinerTipTx = await this.mainWallet.signTransaction(minerTipTx);
            signedTransactions.push(signedMinerTipTx);
            
            console.log('✅ 所有交易已签名');
            console.log(`💰 矿工小费: ${minerTip} ETH`);
            console.log(`📦 捆绑包包含 ${signedTransactions.length} 个交易`);
            
            return {
                signedTransactions,
                targetBlockNumber
            };
            
        } catch (error) {
            console.error('❌ 创建捆绑包时出错:', error);
            throw error;
        }
    }

    async submitBundle(bundle) {
        try {
            console.log('🚀 向 Flashbots 提交捆绑包...');
            
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
            
            return bundleSubmission;
            
        } catch (error) {
            console.error('❌ 提交捆绑包时出错:', error);
            throw error;
        }
    }

    async waitForInclusion(bundleSubmission, maxWaitBlocks = 5) {
        console.log('⏳ 等待捆绑包被包含...');
        
        // 获取当前区块号作为起始点
        const currentBlock = await this.provider.getBlockNumber();
        console.log(`📍 当前区块: ${currentBlock}`);
        
        for (let i = 0; i < maxWaitBlocks; i++) {
            const blockNumber = currentBlock + i + 1; // 从下一个区块开始检查
            const hexBlockNumber = '0x' + blockNumber.toString(16);
            
            try {
                const bundleStats = await this.flashbotsProvider.getBundleStats(
                    bundleSubmission.bundleHash,
                    hexBlockNumber
                );
                
                console.log(`📊 区块 ${blockNumber} (${hexBlockNumber}) 统计:`, bundleStats);
                
                if (bundleStats && bundleStats.isSimulated) {
                    console.log('✅ 捆绑包已被模拟');
                }
                
                if (bundleStats && bundleStats.isMined) {
                    console.log('🎉 捆绑包已被挖矿包含!');
                    return true;
                }
            } catch (error) {
                console.log(`⚠️ 获取区块 ${blockNumber} 统计时出错:`, error.message);
            }
            
            await new Promise(resolve => setTimeout(resolve, 12000));
        }
        
        console.log('❌ 捆绑包在指定区块内未被包含');
        return false;
    }

    async executeMultiUserPresale(keyFiles, presaleAmounts, minerTip = "0.001") {
        try {
            console.log('🚀 开始多用户 NFT 预售 Flashbots 执行');
            
            await this.initWallets(keyFiles);
            await this.initFlashbots();
            
            console.log('🔍 检查合约状态...');
            const isActive = await this.nftContract.isPresaleActive();
            console.log(`📊 预售状态: ${isActive ? '已激活' : '未激活'}`);
            
            const bundle = await this.createMultiUserBundle(presaleAmounts, minerTip);
            const bundleSubmission = await this.submitBundle(bundle);
            const included = await this.waitForInclusion(bundleSubmission);
            
            if (included) {
                console.log('🎉 多用户预售执行成功!');
                
                for (const walletInfo of this.wallets) {
                    const balance = await this.provider.getBalance(walletInfo.address);
                    console.log(`💰 钱包 ${walletInfo.keyFile} 余额: ${ethers.formatEther(balance)} ETH`);
                }
            } else {
                console.log('❌ 捆绑包未被包含，可能需要增加矿工小费或在主网上尝试');
            }
            
        } catch (error) {
            console.error('❌ 执行多用户预售时出错:', error);
            throw error;
        }
    }
}

module.exports = { FlashbotsNFTBundleMultiUser };