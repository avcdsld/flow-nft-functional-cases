// Sender: 0x01
// Mint NFT （Minter: 0x01, Receiver: 0x02）

import NonFungibleToken, MemorablePicture from 0x01

transaction {
    let minter: &MemorablePicture.NFTMinter
    let issuer: Address

    prepare(signer: AuthAccount) {
        self.minter = signer.borrow<&MemorablePicture.NFTMinter>(from: /storage/MemorablePictureNFTMinter)!
        self.issuer = signer.address
    }

    execute {
        let recipient = getAccount(0x02)
            .getCapability(/public/MemorablePictureNFTReceiver)!
            .borrow<&{NonFungibleToken.Receiver}>()!

        // トークン1
        let playerForNFT1: Address = 0x01
        self.minter.mintNFT(
            recipient: recipient,
            issuer: self.issuer,
            players: [playerForNFT1], // 写真に写っている人物のアカウント
            metadata: {
                "image": "https://bit.ly/3cBmJMU",
                "photographer": "Keith Johnston",
                "createdDate": "2020-05-10 09:00:00"
            }
        )

        // トークン2
        let player1ForNFT2: Address = 0x03
        let player2ForNFT2: Address = 0x04
        self.minter.mintNFT(
            recipient: recipient,
            issuer: self.issuer,
            players: [player1ForNFT2, player2ForNFT2],
            metadata: {
                "image": "https://bit.ly/3dRTLbX",
                "photographer": "Eric Rolland",
                "createdDate": "2020-05-10 09:00:00"
            }
        )

        log("Minted two NFTs for 0x02")
    }
}