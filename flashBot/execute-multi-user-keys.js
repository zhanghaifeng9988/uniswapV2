const { FlashbotsNFTBundleMultiUser } = require('./flashbots-bundle-multi-user');

async function executeMultiUserPresale() {
    console.log('🚀 开始多用户 NFT 预售 (使用私钥文件)');
    
    const bundle = new FlashbotsNFTBundleMultiUser();
    
    // 配置参数
    const keyFiles = ['fox1', 'fox2']; // 私钥文件名
    const presaleAmounts = [1, 2]; // 每个钱包购买的NFT数量
    const minerTip = process.argv[2] || "0.002"; // 矿工小费
    
    console.log(`🎯 钱包文件: ${keyFiles.join(', ')}`);
    console.log(`🎯 购买数量: ${presaleAmounts.join(', ')} NFT(s)`);
    console.log(`💰 矿工小费: ${minerTip} ETH`);
    
    await bundle.executeMultiUserPresale(keyFiles, presaleAmounts, minerTip);
}

executeMultiUserPresale().catch(console.error);