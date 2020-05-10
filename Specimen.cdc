// - NonFungibleToken interface
// - Speciment contract

pub contract interface NonFungibleToken {
    pub var totalSupply: UInt64

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)

    pub resource interface INFT {
        pub let id: UInt64
    }

    pub resource NFT: INFT {
        pub let id: UInt64
    }

    pub resource interface Provider {
        pub fun withdraw(withdrawID: UInt64): @NFT {
            post {
                result.id == withdrawID: "The ID of the withdrawn token must be the same as the requested ID"
            }
        }

        pub fun batchWithdraw(ids: [UInt64]): @Collection {
            post {
                result.getIDs().length == ids.length: "Withdrawn collection does not match the requested IDs"
            }
        }
    }

    pub resource interface Receiver {
		pub fun deposit(token: @NFT)
        pub fun batchDeposit(tokens: @Collection)
    }

    pub resource Collection: Provider, Receiver {
        pub var ownedNFTs: @{UInt64: NFT}

        pub fun withdraw(withdrawID: UInt64): @NFT
        pub fun batchWithdraw(ids: [UInt64]): @Collection
        pub fun deposit(token: @NFT)
        pub fun batchDeposit(tokens: @Collection)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NFT
    }

    pub fun createEmptyCollection(): @Collection {
        post {
            result.getIDs().length == 0: "The created collection must be empty!"
        }
    }
}


pub contract Specimen: NonFungibleToken {
    pub var totalSupply: UInt64

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)

    pub resource NFT: NonFungibleToken.INFT {
        pub let id: UInt64
        pub let metadata: {String: String}

        init(initID: UInt64, metadata: {String: String}) {
            self.id = initID
            self.metadata = metadata
        }
    }

    pub resource interface CollectionBorrow {
        pub fun borrowNFT(id: UInt64): &NFT
    }

    pub resource Collection: NonFungibleToken.Provider, NonFungibleToken.Receiver {
        pub var ownedNFTs: @{UInt64: NFT}

        init () {
            self.ownedNFTs <- {}
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

        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        pub fun borrowNFT(id: UInt64): &NFT {
            return &self.ownedNFTs[id] as &NFT
        }

        destroy() {
            destroy self.ownedNFTs
        }
    }

    pub fun createEmptyCollection(): @Collection {
        return <- create Collection()
    }

	pub resource NFTMinter {
		pub fun mintNFT(recipient: &{NonFungibleToken.Receiver}, metadata: {String: String}) {
			var newNFT <- create NFT(initID: Specimen.totalSupply, metadata: metadata)
			recipient.deposit(token: <-newNFT)
            Specimen.totalSupply = Specimen.totalSupply + UInt64(1)
		}
	}

	init() {
        self.totalSupply = 0

        let oldCol <- self.account.load<@Specimen.Collection>(from: /storage/SpecimenCollection)
        destroy oldCol

        let collection <- create Collection()
        self.account.save(<-collection, to: /storage/SpecimenCollection)

        self.account.link<&{NonFungibleToken.Receiver, CollectionBorrow}>(
            /public/NFTReceiver,
            target: /storage/SpecimenCollection
        )

        let minter <- create NFTMinter()
        self.account.save(<-minter, to: /storage/NFTMinter)

        emit ContractInitialized()
	}
}
