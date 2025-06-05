import {
  assert,
  describe,
  test,
  clearStore,
  beforeAll,
  afterAll
} from "matchstick-as/assembly/index"
import { Address, BigInt } from "@graphprotocol/graph-ts"
import { FeeRecipientUpdated } from "../generated/schema"
import { FeeRecipientUpdated as FeeRecipientUpdatedEvent } from "../generated/NFTMarket/NFTMarket"
import { handleFeeRecipientUpdated } from "../src/nft-market"
import { createFeeRecipientUpdatedEvent } from "./nft-market-utils"

// Tests structure (matchstick-as >=0.5.0)
// https://thegraph.com/docs/en/developer/matchstick/#tests-structure-0-5-0

describe("Describe entity assertions", () => {
  beforeAll(() => {
    let newFeeRecipient = Address.fromString(
      "0x0000000000000000000000000000000000000001"
    )
    let newFeeRecipientUpdatedEvent = createFeeRecipientUpdatedEvent(
      newFeeRecipient
    )
    handleFeeRecipientUpdated(newFeeRecipientUpdatedEvent)
  })

  afterAll(() => {
    clearStore()
  })

  // For more test scenarios, see:
  // https://thegraph.com/docs/en/developer/matchstick/#write-a-unit-test

  test("FeeRecipientUpdated created and stored", () => {
    assert.entityCount("FeeRecipientUpdated", 1)

    // 0xa16081f360e3847006db660bae1c6d1b2e17ec2a is the default address used in newMockEvent() function
    assert.fieldEquals(
      "FeeRecipientUpdated",
      "0xa16081f360e3847006db660bae1c6d1b2e17ec2a-1",
      "newFeeRecipient",
      "0x0000000000000000000000000000000000000001"
    )

    // More assert options:
    // https://thegraph.com/docs/en/developer/matchstick/#asserts
  })
})
