// Sender: 0x03
// Add a message to NFT by third person (or the player in the picture)

import NonFungibleToken, MemorablePicture from 0x01

transaction {
    prepare(signer: AuthAccount) {
        let owner: Address = 0x02

        let collectionBorrowRef = getAccount(owner)
            .getCapability(/public/MemorablePictureNFTReceiver)!
            .borrow<&{NonFungibleToken.Receiver, MemorablePicture.CollectionBorrow}>()!

        // Message or comment (or graffiti) on the picture
        let memory <- MemorablePicture.createDraftMemory(
            message: "I like criticism. It makes you strong.",
            graffiti: "" // You can also add graffiti as svg
        )

        // Save to the account storage once to identify who sent the message
        signer.save(<-memory, to: /storage/DraftMemory)
        let memoryRef = signer.borrow<&MemorablePicture.DraftMemory>(from: /storage/DraftMemory)!

        // Add Message to the picture
        collectionBorrowRef.addMemory(id: 1, memory: memoryRef)

        // Destroy a message that has already been sent
        let createdMemory <- signer.load<@MemorablePicture.DraftMemory>(from: /storage/DraftMemory)
        destroy createdMemory

        log("Added a message to a NFT by the third person (or maybe the player in the picture)")

        // Show messages of the NFT
        // If the sender is the person who is in the picture, isPlayer is true. The NFT may have a special value.
        let token = collectionBorrowRef.borrowNFT(id: 1)
        log("nft's memories:")
        log(token.getMemories())
    }
}
