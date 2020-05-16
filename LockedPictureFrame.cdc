import NonFungibleToken, MemorablePicture from 0x01

pub contract LockedPictureFrame: NonFungibleToken {
    pub var totalSupply: UInt64
    pub var keyIdCount: UInt64

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)

    // Key to open the locked picture frame
    pub resource Key {
        pub let id: UInt64
        pub let pictureFrameId: UInt64

        init(id: UInt64, pictureFrameId: UInt64) {
            self.id = id
            self.pictureFrameId = pictureFrameId
        }
    }

    pub resource NFT: NonFungibleToken.INFT {
        pub let id: UInt64
        access(contract) var ownedPictures: @MemorablePicture.Collection
        access(contract) var returnAddress: Address

        init(id: UInt64, pictures: @MemorablePicture.Collection, returnAddress: Address) {
            self.id = id
            self.ownedPictures <- pictures
            self.returnAddress = returnAddress
        }

        destroy() {
            if (self.returnAddress != nil) {
                let capability = getAccount(self.returnAddress).getCapability(/public/MemorablePictureCollection)
                if (capability != nil) {
                    let receiver = capability!.borrow<&{NonFungibleToken.Receiver}>()!
                    receiver.batchDeposit(tokens: <-self.ownedPictures)
                } else {
                    destroy self.ownedPictures
                }
            } else {
                destroy self.ownedPictures
            }
        }
    }

    pub resource interface CollectionBorrow {
        pub fun borrowNFT(id: UInt64): &NFT
        pub fun getBackNFT(id: UInt64)
    }

    // Extended Receiver interface with depositKey function
    pub resource interface Receiver {
        pub fun deposit(token: @NFT)
        pub fun batchDeposit(tokens: @Collection)
		pub fun depositKey(token: @Key)
    }

    pub resource Collection: NonFungibleToken.Provider, NonFungibleToken.Receiver {
        pub var ownedNFTs: @{UInt64: NFT}
        pub var ownedKeys: @{UInt64: Key}

        init () {
            self.ownedNFTs <- {}
            self.ownedKeys <- {}
        }

        pub fun withdraw(withdrawID: UInt64): @NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")
            emit Withdraw(id: token.id, from: self.owner?.address)
            return <-token
        }

        pub fun batchWithdraw(ids: [UInt64]): @Collection {
            let batchCollection <- create Collection()
            for id in ids {
                let nft <- self.withdraw(withdrawID: id)
                batchCollection.deposit(token: <-nft)
            }
            return <-batchCollection
        }

        pub fun deposit(token: @NFT) {
            let id: UInt64 = token.id
            let oldToken <- self.ownedNFTs[id] <- token
            emit Deposit(id: id, to: self.owner?.address)
            destroy oldToken
        }

        pub fun batchDeposit(tokens: @Collection) {
            for id in tokens.getIDs() {
                let nft <- tokens.withdraw(withdrawID: id)
                self.deposit(token: <-nft)
            }
            destroy tokens
        }

        pub fun withdrawKey(withdrawID: UInt64): @Key {
            let token <- self.ownedKeys.remove(key: withdrawID) ?? panic("missing NFT")
            return <-token
        }

        pub fun depositKey(token: @Key) {
            let id: UInt64 = token.id
            let oldToken <- self.ownedKeys[id] <- token
            destroy oldToken
        }

        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        pub fun borrowNFT(id: UInt64): &NFT {
            return &self.ownedNFTs[id] as &NFT
        }

        // 借用タグに書かれている貸主に NFT を返す
        pub fun getBackNFT(id: UInt64) {
            /*
            let token <- self.ownedNFTs.remove(key: id) ?? panic("missing NFT")

            let tag <- token.borrowingTag.remove(key: "BorrowingTag") ?? panic("missing borrowingTag")
            let receiver = getAccount(tag.lender)
                    .getCapability(/public/NFTReceiver)!
                    .borrow<&{NonFungibleToken.Receiver}>()!
            destroy tag

            emit Withdraw(id: token.id, from: self.owner?.address)
            receiver.deposit(token: <-token)
            */
        }

        destroy() {
            destroy self.ownedNFTs
            destroy self.ownedKeys
        }
    }

    pub fun createEmptyCollection(): @Collection {
        return <- create Collection()
    }

    pub fun mintNFT(recipient: &{Receiver}, pictures: @MemorablePicture.Collection, returnAddress: Address, keyNum: UInt8) {
        let pictureFrame <- create NFT(id: LockedPictureFrame.totalSupply, pictures: <-pictures, returnAddress: returnAddress)
        recipient.deposit(token: <-pictureFrame)

        if (keyNum == UInt8(0)) {
            panic("keyNum must be 1 or greater")
        }
        var i: UInt8 = 0
        while i < keyNum {
            let key <- create Key(id: LockedPictureFrame.keyIdCount, pictureFrameId: LockedPictureFrame.totalSupply)
            recipient.depositKey(token: <-key)
            LockedPictureFrame.keyIdCount = LockedPictureFrame.keyIdCount + UInt64(1)
            i = i + UInt8(1)
        }

        LockedPictureFrame.totalSupply = LockedPictureFrame.totalSupply + UInt64(1)
    }

	init() {
        self.totalSupply = 0
        self.keyIdCount = 0

        let oldCol <- self.account.load<@LockedPictureFrame.Collection>(from: /storage/LockedPictureFrameCollection)
        destroy oldCol

        let collection <- create Collection()
        self.account.save(<-collection, to: /storage/LockedPictureFrameCollection)

        self.account.link<&{NonFungibleToken.Receiver, Receiver, CollectionBorrow}>(
            /public/LockedPictureFrameNFTReceiver,
            target: /storage/LockedPictureFrameCollection
        )

        emit ContractInitialized()
	}
}
