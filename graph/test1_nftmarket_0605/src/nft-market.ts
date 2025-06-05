//处理区块链事件并更新数据库的核心逻辑
import {
  FeeRecipientUpdated as FeeRecipientUpdatedEvent,
  NFTBought as NFTBoughtEvent,
  NFTListed as NFTListedEvent,
  NFTUnlisted as NFTUnlistedEvent,
  OwnershipTransferred as OwnershipTransferredEvent,
  PlatformFeeUpdated as PlatformFeeUpdatedEvent,
  SignerUpdated as SignerUpdatedEvent
} from "../generated/NFTMarket/NFTMarket"

import {
  FeeRecipientUpdated,
  NFTBought,
  NFTListed,
  NFTUnlisted,
  OwnershipTransferred,
  PlatformFeeUpdated,
  SignerUpdated,
  NFTTrade
} from "../generated/schema"

export function handleFeeRecipientUpdated(
  event: FeeRecipientUpdatedEvent
): void {
  let entity = new FeeRecipientUpdated(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.newFeeRecipient = event.params.newFeeRecipient

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleNFTBought(event: NFTBoughtEvent): void {
  let entity = new NFTBought(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.nftContract = event.params.nftContract
  entity.tokenId = event.params.tokenId
  entity.buyer = event.params.buyer
  entity.price = event.params.price

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  // 更新 NFTTrade
  let tradeId = event.params.nftContract.toHexString() + "-" + event.params.tokenId.toString()
  let trade = NFTTrade.load(tradeId)
  if (trade) {
    trade.buyer = event.params.buyer
    trade.salePrice = event.params.price
    trade.sold = true
    trade.soldAt = event.block.timestamp
    trade.save()
  }

  entity.save()
}

export function handleNFTListed(event: NFTListedEvent): void {
  let entity = new NFTListed(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.nftContract = event.params.nftContract
  entity.tokenId = event.params.tokenId
  entity.seller = event.params.seller
  entity.price = event.params.price

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()

  // 创建或更新 NFTTrade
  let tradeId = event.params.nftContract.toHexString() + "-" + event.params.tokenId.toString()
  let trade = new NFTTrade(tradeId)
  trade.nftContract = event.params.nftContract
  trade.tokenId = event.params.tokenId
  trade.seller = event.params.seller
  trade.listPrice = event.params.price
  trade.listed = true
  trade.sold = false
  trade.createdAt = event.block.timestamp
  trade.listingEvent = entity.id

  trade.save()
}

export function handleNFTUnlisted(event: NFTUnlistedEvent): void {
  let entity = new NFTUnlisted(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.nftContract = event.params.nftContract
  entity.tokenId = event.params.tokenId
  entity.seller = event.params.seller

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleOwnershipTransferred(
  event: OwnershipTransferredEvent
): void {
  let entity = new OwnershipTransferred(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.previousOwner = event.params.previousOwner
  entity.newOwner = event.params.newOwner

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handlePlatformFeeUpdated(event: PlatformFeeUpdatedEvent): void {
  let entity = new PlatformFeeUpdated(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.newFeePercentage = event.params.newFeePercentage

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleSignerUpdated(event: SignerUpdatedEvent): void {
  let entity = new SignerUpdated(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.newSigner = event.params.newSigner

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}
