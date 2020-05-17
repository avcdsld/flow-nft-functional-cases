// Sender: 0x02
// Add a message to NFT by the owner

import NonFungibleToken, MemorablePicture from 0x01

transaction {
    prepare(signer: AuthAccount) {
        let collectionRef = signer.borrow<&MemorablePicture.Collection>(from: /storage/MemorablePictureCollection)!

        // Message or comment (or graffiti) on the picture
        let memory <- MemorablePicture.createDraftMemory(
            message: "This is a cool photo!",
            graffiti: "" // You can also add graffiti as svg
        )

        // Save to the account storage once to identify who sent the message
        signer.save(<-memory, to: /storage/DraftMemory)
        let memoryRef = signer.borrow<&MemorablePicture.DraftMemory>(from: /storage/DraftMemory)!

        // Add Message to the picture
        collectionRef.addMemory(id: 0, memory: memoryRef)

        // You can also delete the message if you are the owner
        // collectionRef.removeMemory(id: 0, memoryId: 0)

        // Destroy a message that has already been sent
        let createdMemory <- signer.load<@MemorablePicture.DraftMemory>(from: /storage/DraftMemory)
        destroy createdMemory

        log("Added a message to a NFT by the owner (0x02)")

        // Show messages of the NFT
        let token = collectionRef.borrowNFT(id: 0)
        log("nft's memories:")
        log(token.getMemories())
    }
}
