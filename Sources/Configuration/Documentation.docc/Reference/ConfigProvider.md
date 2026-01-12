# ``Configuration/ConfigProvider``

## Topics

### Required methods
- ``ConfigProvider/providerName``
- ``ConfigProvider/value(forKey:type:)``
- ``ConfigProvider/fetchValue(forKey:type:)``
- ``ConfigProvider/watchValue(forKey:type:updatesHandler:)``
- ``ConfigProvider/snapshot()``
- ``ConfigProvider/watchSnapshot(updatesHandler:)``

### Conveniences
- ``ConfigProvider/watchValueFromValue(forKey:type:updatesHandler:)``
- ``ConfigProvider/watchSnapshotFromSnapshot(updatesHandler:)``
- ``ConfigProvider/mapKeys(_:)``
- ``ConfigProvider/prefixKeys(with:)``

### Related guides
- <doc:Implementing-a-provider>
