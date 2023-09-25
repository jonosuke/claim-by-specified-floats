# Overview
Suppose that multiple study sessions were held.

You want to give a FLOAT as a certificate of completion to those who participated in all of the study sessions.

Under the current FLOAT system, the administrator has to check the FLOATs that the participants have, so I can specify FLOATs from other events as a condition for minting.

## Explanation
## Idea
I am in a local community studying Cadence. I thought it would be nice if I could be granted a FLOAT as a certificate of completion when I attend all the study sessions organized by that community.

In the current FLOAT system, the following steps are used to grant FLOAT.

1. create an event for each study session
2. create an event for the FLOAT that will grant the certificate of completion
3. the administrator grants the FLOAT described in 2. to the person who has all the FLOATs for the event created in 1.

Since it is very hard work to check the FLOATs of participants, we have made it possible to specify the FLOATs of other events as a condition for minting.

## What was difficult
It was very difficult to create the environment for testing. When we tried to deploy all the contracts in the repository to the emulator, we got a lot of errors and had a hard time dealing with them.

Since there were some that we did not know how to deal with, we finally decided to deploy only the following contracts. Also, in FLOAT.cdc, there was a section that specified ```0x5643fd47a29770e7```, so I changed it to the address of the emulator-account.

```
"deployments": {
    "emulator": {
        "emulator-account": [
            "FLOAT",
            "FindViews",
            "GrantedAccountAccess",
            "FLOATEventSeries",
            "FLOATVerifiers"
        ],
        "jonosuke": [
            "MyFLOATVerifiers"
        ]
    }
}
```

## What I like about Cadence.
The Resource and move operators were very interesting. The fact that the original variable becomes empty when moved is something I have never experienced before, so it was very new to me.

## About implementation
### MyFLOATVerifiers.cdc
[MyFLOATVerifiers.cdc](https://github.com/jonosuke/claim-by-specified-floats/blob/main/float/MyFLOATVerifiers.cdc)

I noticed that the type of Verifier in FLOAT.verifyAndMint() is ``AnyStruct{FLOAT.IVerifier}``, so I can use my own defined contract as Verifier.

The basic implementation is based on the implementation in [FLOATVerifiers.cdc](https://github.com/emerald-dao/float/blob/main/src/cadence/float/FLOATVerifiers.cdc). It is almost the same as the other Verifier, except for the process of checking to see if user have the FLOAT needed to do the minting

The code below confirms that user have the necessary FLOAT to mint.
```
for eventId in self.eventIds {
    assert(
        floatCollection.ownedIdsFromEvent(eventId: eventId).length > 0,
        message: "You do not have FLOAT from Event#".concat(eventId.toString())
    )
}
```

floatCollection.ownedIdsFromEvent() returns an array of FLOAT IDs corresponding to eventId, so we check if the array size is greater than 0.

### my_create_event.cdc
[my_create_event.cdc](https://github.com/jonosuke/claim-by-specified-floats/blob/main/float/transactions/my_create_event.cdc)

A transaction that creates an event, based on [create_event.cdc in the float repository](https://github.com/emerald-dao/float/blob/main/src/cadence/float/transactions/create_event.cdc).

The two changes from create_event.cdc are as follows.

1. receive as an argument an array of FLOAT event IDs required for minting
2. if the array received in 1. contains event IDs, add MyFLOATVerifiers as Verifier
```
if let eventIds = requiredEventIdsForClaim {
    if eventIds.length > 0 {
        ClaimBySpecifiedFLOATs = FLOATVerifiers.ClaimBySpecifiedFLOATs(_eventIds: eventIds)
        verifiers.append(ClaimBySpecifiedFLOATs!)
    }
}
```

### FLOAT.cdc
Changed ``0x5643fd47a29770e7`` on lines 168 and 764 to the address of the emulator-account. This change was made to avoid errors when deploying.

# Test
1. start the emulator
```
cd claim-by-specified-floats
flow emulator -v
```
2. create an account
```
// create jonosuke(0xfd43f9148d4b725d)
flow accounts create
// create yanosuke(0xeb179c27144f783c)
flow accounts create
```
3. deploy

Change deployments in flow.json as follows and deploy.
```
"deployments": {
    "emulator": {
        "emulator-account": [
            "FLOAT",
            "FindViews",
            "GrantedAccountAccess",
            "FLOATEventSeries",
            "FLOATVerifiers"
        ],
        "jonosuke": [
            "MyFLOATVerifiers"
        ]
    }
}
```
```
flow project deploy
```
4. Account Setup
```
flow transactions send float/transactions/setup_account.cdc --signer=jonosuke
flow transactions send float/transactions/setup_account.cdc --signer=yanosuke
```
5. event creation

All IDs used are examples.
```
// 'eventId = 5044031582654955520' is created
flow transactions send float/transactions/my_create_event.cdc fd43f9148d4b725d true Test 'Test Description' Akabeko "" false false 0.0 0.0 false "" false 0 '[]' false 0.0 false 0.0 false nil nil nil '[]' --signer=jonosuke

// 'event_id = 13835058055282163712' is created
flow transactions send float/transactions/my_create_event.cdc fd43f9148d4b725d true Test2 'Test Description' Akabeko "" false false 0.0 0.0 false "" false 0 '[]' false 0.0 false 0.0 false nil nil nil '[]' --signer=jonosuke

// 'event_id = 4035225266123964416' is created
flow transactions send float/transactions/my_create_event.cdc fd43f9148d4b725d true Test3 'Test Description' Akabeko "" false false 0.0 0.0 false "" false 0 '[]' false 0.0 false 0.0 false nil nil nil '[]' --signer=jonosuke

// 'event_id = 10736581511651262464' is created. Specify 'event_id = 13835058055282163712' and 'event_id = 4035225266123964416' for the mint condition
flow transactions send float/transactions/my_create_event.cdc fd43f9148d4b725d true Test4 'Test Description' Akabeko "" false false 0.0 0.0 false "" false 0 '[]' false 0.0 false 0.0 false nil nil nil '[13835058055282163712,4035225266123964416]' --signer=jonosuke
```
6. mint of FLOAT
```
// Fails because it does not meet the requirements to be able to mint.
flow transactions send float/transactions/claim.cdc 10736581511651262464 fd43f9148d4b725d nil --signer=yanosuke

// Unconditionally mintable
flow transactions send float/transactions/claim.cdc 5044031582654955520 fd43f9148d4b725d nil --signer=yanosuke

// Fails because it does not yet meet the conditions to be able to mint.
flow transactions send float/transactions/claim.cdc 10736581511651262464 fd43f9148d4b725d nil --signer=yanosuke

// Unconditionally mintable
flow transactions send float/transactions/claim.cdc 13835058055282163712 fd43f9148d4b725d nil --signer=yanosuke

// Fails because it does not yet meet the conditions to be able to mint.
flow transactions send float/transactions/claim.cdc 10736581511651262464 fd43f9148d4b725d nil --signer=yanosuke

// Unconditionally mintable
flow transactions send float/transactions/claim.cdc 4035225266123964416 fd43f9148d4b725d nil --signer=yanosuke

// succeeds because it meets the conditions to be able to mint it.
flow transactions send float/transactions/claim.cdc 10736581511651262464 fd43f9148d4b725d nil --signer=yanosuke
```