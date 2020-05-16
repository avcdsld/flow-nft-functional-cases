// Sender: 0x02
// Setup to receive NFT

import NonFungibleToken, MemorablePicture from 0x01

transaction {
    prepare(signer: AuthAccount) {
        let collection <- MemorablePicture.createEmptyCollection()

        // let oldCol <- signer.load<@MemorablePicture.Collection>(from: /storage/MemorablePictureCollection)
        // destroy oldCol

        signer.save(<-collection, to: /storage/MemorablePictureCollection)

        signer.link<&{NonFungibleToken.Receiver, MemorablePicture.CollectionBorrow}>(
            /public/MemorablePictureNFTReceiver,
            target: /storage/MemorablePictureCollection
        )

        log("Completed setup of account 0x02 to receive NFT")
    }
}