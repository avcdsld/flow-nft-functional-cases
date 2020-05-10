import NonFungibleToken, Specimen from 0x01

pub contract LockedSpecimenCase: NonFungibleToken {
    pub var totalSupply: UInt64
    pub var totalSupplyForKey: UInt64

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)

    // ロックされたケースを開けるためのキー
    pub resource KeyNFT: NonFungibleToken.INFT {
        pub let id: UInt64
        pub let caseId: UInt64

        init(id: UInt64, caseId: UInt64) {
            self.id = id
            self.caseId = caseId
        }
    }

    pub resource NFT: NonFungibleToken.INFT {
        pub let id: UInt64
        access(contract) var ownedSpecimens: @Specimen.Collection
        access(contract) var returnAddress: Address
        access(contract) var histories: [String]

        init(id: UInt64, specimens: @Specimen.Collection, returnAddress: Address) {
            self.id = id
            self.ownedSpecimens <- specimens
            self.returnAddress = returnAddress
            self.histories = []
        }

        pub fun addCustomHistory(message: String) {
            self.histories.append("[Custom] ".concat(message))
        }

        destroy() {
            if (self.returnAddress != nil) {
                let capability = getAccount(self.returnAddress).getCapability(/public/SpecimenCollection)
                if (capability != nil) {
                    let receiver = capability!.borrow<&{NonFungibleToken.Receiver}>()!
                    receiver.batchDeposit(tokens: <-self.ownedSpecimens)
                } else {
                    destroy self.ownedSpecimens
                }
            } else {
                destroy self.ownedSpecimens
            }
        }
    }

    pub resource interface CollectionBorrow {
        pub fun borrowNFT(id: UInt64): &NFT
        pub fun getBackNFT(id: UInt64)
    }

    pub resource interface Receiver {
        pub fun deposit(token: @NFT)
        pub fun batchDeposit(tokens: @Collection)
		pub fun depositKey(token: @KeyNFT)
    }

    pub resource Collection: NonFungibleToken.Provider, NonFungibleToken.Receiver {
        pub var ownedNFTs: @{UInt64: NFT}
        pub var ownedKeyNFTs: @{UInt64: KeyNFT}

        init () {
            self.ownedNFTs <- {}
            self.ownedKeyNFTs <- {}
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

        pub fun withdrawKey(withdrawID: UInt64): @KeyNFT {
            let token <- self.ownedKeyNFTs.remove(key: withdrawID) ?? panic("missing NFT")
            return <-token
        }

        pub fun depositKey(token: @KeyNFT) {
            let id: UInt64 = token.id
            let oldToken <- self.ownedKeyNFTs[id] <- token
            destroy oldToken
        }

        /*
        // NFTに借用タグを付ける
        pub fun attachBorrowingTag(id: UInt64) {
            let token <- self.ownedNFTs.remove(key: id) ?? panic("missing NFT")

            let creator = self.owner!.address
            token.borrowingTag["BorrowingTag"] <-! create BorrowingTag(creator: creator, lender: creator)

            self.ownedNFTs[id] <-! token
        }
        */

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
            destroy self.ownedKeyNFTs
        }
    }

    pub fun createEmptyCollection(): @Collection {
        return <- create Collection()
    }

    pub fun mintNFT(recipient: &{Receiver}, specimens: @Specimen.Collection, returnAddress: Address, keyNum: UInt8) {
        let case <- create NFT(id: LockedSpecimenCase.totalSupply, specimens: <-specimens, returnAddress: returnAddress)
        recipient.deposit(token: <-case)

        if (keyNum == UInt8(0)) {
            panic("keyNum must be 1 or greater")
        }
        var i: UInt8 = 0
        while i < keyNum {
            let key <- create KeyNFT(id: LockedSpecimenCase.totalSupplyForKey, caseId: LockedSpecimenCase.totalSupply)
            recipient.depositKey(token: <-key)
            LockedSpecimenCase.totalSupplyForKey = LockedSpecimenCase.totalSupplyForKey + UInt64(1)
            i = i + UInt8(1)
        }

        LockedSpecimenCase.totalSupply = LockedSpecimenCase.totalSupply + UInt64(1)
    }

	init() {
        self.totalSupply = 0
        self.totalSupplyForKey = 0

        let oldCol <- self.account.load<@LockedSpecimenCase.Collection>(from: /storage/LockedSpecimenCaseCollection)
        destroy oldCol

        let collection <- create Collection()
        self.account.save(<-collection, to: /storage/LockedSpecimenCaseCollection)

        self.account.link<&{NonFungibleToken.Receiver, Receiver, CollectionBorrow}>(
            /public/NFTReceiver,
            target: /storage/LockedSpecimenCaseCollection
        )

        emit ContractInitialized()
	}
}
