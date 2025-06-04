const { FlashbotsNFTBundle } = require('./flashbots-bundle');

async function executePresale() {
    console.log('🚀 Starting NFT Presale with Flashbots');
    
    const bundle = new FlashbotsNFTBundle();
    
    // 执行捆绑交易，购买指定数量的NFT
    const presaleAmount = process.argv[2] ? parseInt(process.argv[2]) : 1;
    const minerTip = process.argv[3] || "0.001"; // 默认矿工费用 0.001 ETH
    
    console.log(`🎯 Target: Purchase ${presaleAmount} NFT(s)`);
    console.log(`💰 Miner tip: ${minerTip} ETH`);
    
    await bundle.executeFlashbotsPresale(presaleAmount, minerTip);
}

executePresale().catch(console.error);