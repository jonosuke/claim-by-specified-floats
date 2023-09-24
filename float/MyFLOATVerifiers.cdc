import FLOAT from "./FLOAT.cdc"

pub contract MyFLOATVerifiers {
    //
    // ClaimByMultipleEvents
    //
    // Requires the specified FLOATs
    pub struct ClaimBySpecifiedFLOATs: FLOAT.IVerifier {
        pub let eventIds: [UInt64]

        pub fun verify(_ params: {String: AnyStruct}) {
            let claimee: Address = params["claimee"]! as! Address
            if let floatCollection = getAccount(claimee)
                .getCapability(FLOAT.FLOATCollectionPublicPath)
                .borrow<&FLOAT.Collection{FLOAT.CollectionPublic}>() {
                for eventId in self.eventIds {
                    assert(
                        floatCollection.ownedIdsFromEvent(eventId: eventId).length > 0,
                        message: "You do not have FLOAT from Event#".concat(eventId.toString())
                    )
                }
            } else {
                panic("Could not borrow the Collection from the account.")
            }
        }

        init(_eventIds: [UInt64]) {
            pre {
                _eventIds.length > 0: "You must specify at least one event."
            }
            self.eventIds = _eventIds
        }
    }
}