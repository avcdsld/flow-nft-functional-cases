// - NonFungibleToken interface
// - MemorablePicture contract

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


pub contract MemorablePicture: NonFungibleToken {
    pub var totalSupply: UInt64
    pub var memoryIdCount: UInt64

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)

    pub resource DraftMemory {
        pub var message: String
        pub var graffiti: String

        init(message: String, graffiti: String) {
            self.message = message
            self.graffiti = graffiti
        }
    }

    pub resource Memory {
        pub let id: UInt64
        pub let sender: Address
        pub let isPlayer: Bool
        pub let message: String
        pub let graffiti: String

        init(id: UInt64, sender: Address, isPlayer: Bool, message: String, graffiti: String) {
            self.id = id
            self.sender = sender
            self.isPlayer = isPlayer
            self.message = message
            self.graffiti = graffiti
        }
    }

    pub resource NFT: NonFungibleToken.INFT {
        pub let id: UInt64
        pub let issuer: Address
        pub let players: [Address]
        access(contract) var metadata: {String: String}
        access(contract) var memories: @{UInt64: Memory}

        init(id: UInt64, issuer: Address, players: [Address], metadata: {String: String}) {
            self.id = id
            self.issuer = issuer
            self.players = players
            self.metadata = metadata
            self.memories <- {}
        }

        pub fun getMetadata(): {String: String} {
            return self.metadata
        }

        pub fun getMemories(): {UInt64: &Memory} {
            var memories: {UInt64: &Memory} = {}
            for id in self.memories.keys {
                memories[id] = &self.memories[id] as &Memory
            }
            return memories
        }
        /*
        pub fun getMemories(): {UInt64: {String: String}} {
            var memories: {UInt64: {String: String}} = {}
            for id in self.memories.keys {
                var memory: {String: String} = {}
                memory["message"] = self.memories[id]?.message
                memory["graffiti"] = self.memories[id]?.graffiti
                // let isPlayer = self.memories[id]?.isPlayer
                // if (isPlayer) {
                //    memory["isPlayer"] = "true"
                //}
                memories[id] = memory
            }
            return memories
        }
        */

        destroy() {
            destroy self.memories
        }
    }

    pub resource interface CollectionBorrow {
        pub fun borrowNFT(id: UInt64): &NFT
        pub fun addMemory(id: UInt64, memory: &DraftMemory)
        pub fun getIDs(): [UInt64]
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

        // 思い出を追加する
        pub fun addMemory(id: UInt64, memory: &DraftMemory) {
            let token <- self.ownedNFTs.remove(key: id) ?? panic("missing NFT")

            let sender = memory.owner?.address ?? panic("draftMemory has no owner!")
            let isPlayer = token.players.contains(sender)
            let newMemory <- create Memory(
                id: MemorablePicture.memoryIdCount,
                sender: sender,
                isPlayer: isPlayer,
                message: memory.message,
                graffiti: memory.graffiti
            )
            token.memories[MemorablePicture.memoryIdCount] <-! newMemory
            MemorablePicture.memoryIdCount = MemorablePicture.memoryIdCount + UInt64(1)

            self.ownedNFTs[id] <-! token
        }

        // 思い出を削除する
        pub fun removeMemory(id: UInt64, memoryId: UInt64) {
            let token <- self.ownedNFTs.remove(key: id) ?? panic("missing NFT")

            let memory <- token.memories.remove(key: memoryId) ?? panic("missing Memory")
            destroy memory

            self.ownedNFTs[id] <-! token
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

    // ドラフトの思い出リソースを作成する
    pub fun createDraftMemory(message: String, graffiti: String): @DraftMemory {
        return <- create DraftMemory(message: message, graffiti: graffiti)
    }

	pub resource NFTMinter {
		pub fun mintNFT(recipient: &{NonFungibleToken.Receiver}, issuer: Address, players: [Address], metadata: {String: String}) {
			var newNFT <- create NFT(id: MemorablePicture.totalSupply, issuer: issuer, players: players, metadata: metadata)
			recipient.deposit(token: <-newNFT)
            MemorablePicture.totalSupply = MemorablePicture.totalSupply + UInt64(1)
		}
	}

	init() {
        self.totalSupply = 0
        self.memoryIdCount = 0

        let oldCol <- self.account.load<@MemorablePicture.Collection>(from: /storage/MemorablePictureCollection)
        destroy oldCol

        let collection <- create Collection()
        self.account.save(<-collection, to: /storage/MemorablePictureCollection)

        self.account.link<&{NonFungibleToken.Receiver, CollectionBorrow}>(
            /public/MemorablePictureNFTReceiver,
            target: /storage/MemorablePictureCollection
        )

        let minter <- create NFTMinter()
        self.account.save(<-minter, to: /storage/MemorablePictureNFTMinter)

        emit ContractInitialized()
	}
}
