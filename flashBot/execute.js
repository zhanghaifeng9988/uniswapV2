const { FlashbotsNFTBundle } = require('./flashbots-bundle');

async function executePresale() {
    console.log('🚀 Starting NFT Presale with Flashbots');
    
    const bundle = new FlashbotsNFTBundle();
    
    // 执行捆绑交易，购买指定数量的NFT
    const presaleAmount = process.argv[2] ? parseInt(process.argv[2]) : 1;
    
    console.log(`🎯 Target: Purchase ${presaleAmount} NFT(s)`);
    
    await bundle.executeFlashbotsPresale(presaleAmount);
}

executePresale().catch(console.error);