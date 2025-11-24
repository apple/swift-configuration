# ``Configuration/ConfigSnapshotReader``

## Topics

### Creating a snapshot
- ``ConfigReader/snapshot()``
- ``ConfigReader/watchSnapshot(fileID:line:updatesHandler:)``

### Namespacing
- ``ConfigSnapshotReader/scoped(to:context:keyDecoderOverride:)``
- ``ConfigSnapshotReader/scoped(to:keyDecoderOverride:)``

### Synchronously reading string values
- ``ConfigSnapshotReader/string(forKey:isSecret:fileID:line:)``
- ``ConfigSnapshotReader/string(forKey:isSecret:default:fileID:line:)``
- ``ConfigSnapshotReader/string(forKey:as:isSecret:fileID:line:)-8hlcf``
- ``ConfigSnapshotReader/string(forKey:as:isSecret:fileID:line:)-7bpif``
- ``ConfigSnapshotReader/string(forKey:as:isSecret:default:fileID:line:)-fzpe``
- ``ConfigSnapshotReader/string(forKey:as:isSecret:default:fileID:line:)-2mphx``
- ``ConfigSnapshotReader/string(forKey:context:isSecret:fileID:line:)``
- ``ConfigSnapshotReader/string(forKey:context:as:isSecret:fileID:line:)-4xl9h``
- ``ConfigSnapshotReader/string(forKey:context:as:isSecret:fileID:line:)-2bx31``
- ``ConfigSnapshotReader/string(forKey:context:isSecret:default:fileID:line:)``
- ``ConfigSnapshotReader/string(forKey:context:as:isSecret:default:fileID:line:)-9zl96``
- ``ConfigSnapshotReader/string(forKey:context:as:isSecret:default:fileID:line:)-3azme``

### Synchronously reading lists of string values
- ``ConfigSnapshotReader/stringArray(forKey:isSecret:fileID:line:)``
- ``ConfigSnapshotReader/stringArray(forKey:as:isSecret:fileID:line:)-7athn``
- ``ConfigSnapshotReader/stringArray(forKey:as:isSecret:fileID:line:)-v5ap``
- ``ConfigSnapshotReader/stringArray(forKey:isSecret:default:fileID:line:)``
- ``ConfigSnapshotReader/stringArray(forKey:as:isSecret:default:fileID:line:)-8n896``
- ``ConfigSnapshotReader/stringArray(forKey:as:isSecret:default:fileID:line:)-yx0h``
- ``ConfigSnapshotReader/stringArray(forKey:context:isSecret:fileID:line:)``
- ``ConfigSnapshotReader/stringArray(forKey:context:as:isSecret:fileID:line:)-2cmxo``
- ``ConfigSnapshotReader/stringArray(forKey:context:as:isSecret:fileID:line:)-141zx``
- ``ConfigSnapshotReader/stringArray(forKey:context:isSecret:default:fileID:line:)``
- ``ConfigSnapshotReader/stringArray(forKey:context:as:isSecret:default:fileID:line:)-2hjcv``
- ``ConfigSnapshotReader/stringArray(forKey:context:as:isSecret:default:fileID:line:)-5dkbi``

### Synchronously reading required string values
- ``ConfigSnapshotReader/requiredString(forKey:isSecret:fileID:line:)``
- ``ConfigSnapshotReader/requiredString(forKey:as:isSecret:fileID:line:)-85qdd``
- ``ConfigSnapshotReader/requiredString(forKey:as:isSecret:fileID:line:)-3iy7q``
- ``ConfigSnapshotReader/requiredString(forKey:context:isSecret:fileID:line:)``
- ``ConfigSnapshotReader/requiredString(forKey:context:as:isSecret:fileID:line:)-8cx83``
- ``ConfigSnapshotReader/requiredString(forKey:context:as:isSecret:fileID:line:)-1056``

### Synchronously reading required lists of string values
- ``ConfigSnapshotReader/requiredStringArray(forKey:isSecret:fileID:line:)``
- ``ConfigSnapshotReader/requiredStringArray(forKey:as:isSecret:fileID:line:)-4nuew``
- ``ConfigSnapshotReader/requiredStringArray(forKey:as:isSecret:fileID:line:)-4pyhg``
- ``ConfigSnapshotReader/requiredStringArray(forKey:context:isSecret:fileID:line:)``
- ``ConfigSnapshotReader/requiredStringArray(forKey:context:as:isSecret:fileID:line:)-4e338``
- ``ConfigSnapshotReader/requiredStringArray(forKey:context:as:isSecret:fileID:line:)-5q0ew``

### Synchronously reading Boolean values
- ``ConfigSnapshotReader/bool(forKey:isSecret:fileID:line:)``
- ``ConfigSnapshotReader/bool(forKey:isSecret:default:fileID:line:)``
- ``ConfigSnapshotReader/bool(forKey:context:isSecret:fileID:line:)``
- ``ConfigSnapshotReader/bool(forKey:context:isSecret:default:fileID:line:)``

### Synchronously reading required Boolean values
- ``ConfigSnapshotReader/requiredBool(forKey:isSecret:fileID:line:)``
- ``ConfigSnapshotReader/requiredBool(forKey:context:isSecret:fileID:line:)``

### Synchronously reading lists of Boolean values
- ``ConfigSnapshotReader/boolArray(forKey:isSecret:fileID:line:)``
- ``ConfigSnapshotReader/boolArray(forKey:isSecret:default:fileID:line:)``
- ``ConfigSnapshotReader/boolArray(forKey:context:isSecret:fileID:line:)``
- ``ConfigSnapshotReader/boolArray(forKey:context:isSecret:default:fileID:line:)``

### Synchronously reading required lists of Boolean values
- ``ConfigSnapshotReader/requiredBoolArray(forKey:isSecret:fileID:line:)``
- ``ConfigSnapshotReader/requiredBoolArray(forKey:context:isSecret:fileID:line:)``

### Synchronously reading integer values
- ``ConfigSnapshotReader/int(forKey:isSecret:fileID:line:)``
- ``ConfigSnapshotReader/int(forKey:isSecret:default:fileID:line:)``
- ``ConfigSnapshotReader/int(forKey:context:isSecret:fileID:line:)``
- ``ConfigSnapshotReader/int(forKey:context:isSecret:default:fileID:line:)``

### Synchronously reading required integer values
- ``ConfigSnapshotReader/requiredInt(forKey:isSecret:fileID:line:)``
- ``ConfigSnapshotReader/requiredInt(forKey:context:isSecret:fileID:line:)``

### Synchronously reading lists of integer values
- ``ConfigSnapshotReader/intArray(forKey:isSecret:fileID:line:)``
- ``ConfigSnapshotReader/intArray(forKey:isSecret:default:fileID:line:)``
- ``ConfigSnapshotReader/intArray(forKey:context:isSecret:fileID:line:)``
- ``ConfigSnapshotReader/intArray(forKey:context:isSecret:default:fileID:line:)``

### Synchronously reading required lists of integer values
- ``ConfigSnapshotReader/requiredIntArray(forKey:isSecret:fileID:line:)``
- ``ConfigSnapshotReader/requiredIntArray(forKey:context:isSecret:fileID:line:)``

### Synchronously reading double values
- ``ConfigSnapshotReader/double(forKey:isSecret:fileID:line:)``
- ``ConfigSnapshotReader/double(forKey:isSecret:default:fileID:line:)``
- ``ConfigSnapshotReader/double(forKey:context:isSecret:fileID:line:)``
- ``ConfigSnapshotReader/double(forKey:context:isSecret:default:fileID:line:)``

### Synchronously reading required double values
- ``ConfigSnapshotReader/requiredDouble(forKey:isSecret:fileID:line:)``
- ``ConfigSnapshotReader/requiredDouble(forKey:context:isSecret:fileID:line:)``

### Synchronously reading lists of double values
- ``ConfigSnapshotReader/doubleArray(forKey:isSecret:fileID:line:)``
- ``ConfigSnapshotReader/doubleArray(forKey:isSecret:default:fileID:line:)``
- ``ConfigSnapshotReader/doubleArray(forKey:context:isSecret:fileID:line:)``
- ``ConfigSnapshotReader/doubleArray(forKey:context:isSecret:default:fileID:line:)``

### Synchronously reading required lists of double values
- ``ConfigSnapshotReader/requiredDoubleArray(forKey:isSecret:fileID:line:)``
- ``ConfigSnapshotReader/requiredDoubleArray(forKey:context:isSecret:fileID:line:)``

### Synchronously reading bytes
- ``ConfigSnapshotReader/bytes(forKey:isSecret:fileID:line:)``
- ``ConfigSnapshotReader/bytes(forKey:isSecret:default:fileID:line:)``
- ``ConfigSnapshotReader/bytes(forKey:context:isSecret:fileID:line:)``
- ``ConfigSnapshotReader/bytes(forKey:context:isSecret:default:fileID:line:)``

### Synchronously reading required bytes
- ``ConfigSnapshotReader/requiredBytes(forKey:isSecret:fileID:line:)``
- ``ConfigSnapshotReader/requiredBytes(forKey:context:isSecret:fileID:line:)``

### Synchronously reading collections of byte chunks
- ``ConfigSnapshotReader/byteChunkArray(forKey:isSecret:fileID:line:)``
- ``ConfigSnapshotReader/byteChunkArray(forKey:isSecret:default:fileID:line:)``
- ``ConfigSnapshotReader/byteChunkArray(forKey:context:isSecret:fileID:line:)``
- ``ConfigSnapshotReader/byteChunkArray(forKey:context:isSecret:default:fileID:line:)``

### Synchronously reading required collections of byte chunks
- ``ConfigSnapshotReader/requiredByteChunkArray(forKey:isSecret:fileID:line:)``
- ``ConfigSnapshotReader/requiredByteChunkArray(forKey:context:isSecret:fileID:line:)``
