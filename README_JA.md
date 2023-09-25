# 概要
複数回にわたって勉強会が開催されたとします。

開催された勉強会に全て参加した人に対して、修了証としてFLOATを付与したい場合を考えます。

今のFLOATの仕組みでは、参加者が持っているFLOATを管理者が確認しないといけないので、ミントの条件として他のイベントのFLOATを指定できるようにしました。

# 解説
## アイデアについて
私はCadenceを勉強するローカルコミュニティに入っています。そのコミュニティが主催する勉強会に全て参加したときに、修了証としてFLOATを付与できたら良いなと思いました。

今のFLOATの仕組みでは、下記の手順でFLOATを付与します

1. 勉強会毎にイベントを作成します
2. 修了証を付与するFLOATのイベントを作成します
3. 1.で作成したイベントのFLOATを全て持っている人に対して、管理者が2.のFLOATを付与します

参加者のFLOATを確認するのはとても大変な作業なので、ミントする条件として、他のイベントのFLOATを指定できるようにしました。

## 大変だった事
テスト用の環境を作るのがとても大変でした。レポジトリにあるコントラクトを全てエミュレーターにデプロイしようとすると、大量のエラーが出てきて対応に苦労しました。

対処方法が判らないものがあったので、最終的には下記のコントラクトだけをデプロイするようにしました。また、FLOAT.cdc内で```0x5643fd47a29770e7```を指定している箇所があったので、emulator-accountのアドレスに変更しました。

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

## Cadenceの好きな所
Resourceとmove演算子が非常に興味深かったです。移動させると元の変数が空になるというのは、これまで経験した事がないので、とても新鮮でした。

## 実装について
### MyFLOATVerifiers.cdc
[MyFLOATVerifiers.cdc](https://github.com/jonosuke/claim-by-specified-floats/blob/main/float/MyFLOATVerifiers.cdc)

FLOAT.verifyAndMint()を見るとVerifierの型が```AnyStruct{FLOAT.IVerifier}```になっていたので、自分で定義したコントラクトをVerifierとして使える事に気づきました。

基本的な実装の仕方は、[FLOATVerifiers.cdc](https://github.com/emerald-dao/float/blob/main/src/cadence/float/FLOATVerifiers.cdc)にある実装を参考にしました。ミントに必要なFLOATを持っているのか確認する処理以外は、他のVerifierとほとんど同じです。

下記のコードは、ミントに必要なFLOATを持っているのか確認しています。
```
for eventId in self.eventIds {
    assert(
        floatCollection.ownedIdsFromEvent(eventId: eventId).length > 0,
        message: "You do not have FLOAT from Event#".concat(eventId.toString())
    )
}
```

floatCollection.ownedIdsFromEvent()は、eventIdに対応したFLOATのIDの配列を返すので、配列の大きさが0より大きいか確認しています。

### my_create_event.cdc
[my_create_event.cdc](https://github.com/jonosuke/claim-by-specified-floats/blob/main/float/transactions/my_create_event.cdc)

イベントを作成するトランザクションです。[floatレポジトリにあるcreate_event.cdc](https://github.com/emerald-dao/float/blob/main/src/cadence/float/transactions/create_event.cdc)を元に作成しています。

create_event.cdcからの変更点は下記の二点です。

1. ミントに必要なFLOATのイベントIDの配列を、引数として受け取ります
2. 1.の配列にイベントIDが入っている場合、MyFLOATVerifiersをVerifierとして追加します
```
if let eventIds = requiredEventIdsForClaim {
    if eventIds.length > 0 {
        ClaimBySpecifiedFLOATs = FLOATVerifiers.ClaimBySpecifiedFLOATs(_eventIds: eventIds)
        verifiers.append(ClaimBySpecifiedFLOATs!)
    }
}
```

### FLOAT.cdc
168行目と764行目の```0x5643fd47a29770e7```を、emulator-accountのアドレスに変更しました。これはデプロイしたときにエラーが出ないようにするための変更です。

# Test
1. エミュレーターの起動
```
cd claim-by-specified-floats
flow emulator -v
```
2. アカウント作成
```
// jonosuke(0xfd43f9148d4b725d)を作る
flow accounts create
// yanosuke(0xeb179c27144f783c)を作る
flow accounts create
```
3. デプロイ

flow.jsonのdeploymentsを下記のように変更してデプロイします。
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
4. アカウントのセットアップ
```
flow transactions send float/transactions/setup_account.cdc --signer=jonosuke
flow transactions send float/transactions/setup_account.cdc --signer=yanosuke
```
5. イベントの作成

使っているIDは全て例です。
```
// 'eventId = 5044031582654955520' が作成される
flow transactions send float/transactions/my_create_event.cdc fd43f9148d4b725d true Test 'Test Description' Akabeko "" false false 0.0 0.0 false "" false 0 '[]' false 0.0 false 0.0 false nil nil nil '[]' --signer=jonosuke

// 'event_id = 13835058055282163712' が作成される
flow transactions send float/transactions/my_create_event.cdc fd43f9148d4b725d true Test2 'Test Description' Akabeko "" false false 0.0 0.0 false "" false 0 '[]' false 0.0 false 0.0 false nil nil nil '[]' --signer=jonosuke

// 'event_id = 4035225266123964416' が作成される
flow transactions send float/transactions/my_create_event.cdc fd43f9148d4b725d true Test3 'Test Description' Akabeko "" false false 0.0 0.0 false "" false 0 '[]' false 0.0 false 0.0 false nil nil nil '[]' --signer=jonosuke

// 'event_id = 10736581511651262464' が作成される。ミントの条件に、'event_id = 13835058055282163712'と'event_id = 4035225266123964416'を指定
flow transactions send float/transactions/my_create_event.cdc fd43f9148d4b725d true Test4 'Test Description' Akabeko "" false false 0.0 0.0 false "" false 0 '[]' false 0.0 false 0.0 false nil nil nil '[13835058055282163712,4035225266123964416]' --signer=jonosuke
```
6. FLOATのミント
```
// ミントできる条件を満たしていないので失敗する
flow transactions send float/transactions/claim.cdc 10736581511651262464 fd43f9148d4b725d nil --signer=yanosuke

// 無条件でミントできる
flow transactions send float/transactions/claim.cdc 5044031582654955520 fd43f9148d4b725d nil --signer=yanosuke

// ミントできる条件をまだ満たしていないので失敗する
flow transactions send float/transactions/claim.cdc 10736581511651262464 fd43f9148d4b725d nil --signer=yanosuke

// 無条件でミントできる
flow transactions send float/transactions/claim.cdc 13835058055282163712 fd43f9148d4b725d nil --signer=yanosuke

// ミントできる条件をまだ満たしていないので失敗する
flow transactions send float/transactions/claim.cdc 10736581511651262464 fd43f9148d4b725d nil --signer=yanosuke

// 無条件でミントできる
flow transactions send float/transactions/claim.cdc 4035225266123964416 fd43f9148d4b725d nil --signer=yanosuke

// ミントできる条件を満たしたので成功する
flow transactions send float/transactions/claim.cdc 10736581511651262464 fd43f9148d4b725d nil --signer=yanosuke
```