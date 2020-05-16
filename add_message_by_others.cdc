// Sender: 0x03
// Add a message to NFT by third person (or the player in the picture)

import NonFungibleToken, MemorablePicture from 0x01

transaction {
    prepare(signer: AuthAccount) {
        let owner: Address = 0x02

        let collectionBorrowRef = getAccount(owner)
            .getCapability(/public/MemorablePictureNFTReceiver)!
            .borrow<&{NonFungibleToken.Receiver, MemorablePicture.CollectionBorrow}>()!

        let memory <- MemorablePicture.createDraftMemory(
            message: "I like criticism. It makes you strong.",
            graffiti: ""
        )

        signer.save(<-memory, to: /storage/DraftMemory)
        let memoryRef = signer.borrow<&MemorablePicture.DraftMemory>(from: /storage/DraftMemory)!

        collectionBorrowRef.addMemory(id: 1, memory: memoryRef)

        let createdMemory <- signer.load<@MemorablePicture.DraftMemory>(from: /storage/DraftMemory)
        destroy createdMemory

        log("Added a message to a NFT by the third person (or maybe the player in the picture)")

        let token = collectionBorrowRef.borrowNFT(id: 1)
        log("nft's memories:")
        log(token.getMemories())
    }
}
