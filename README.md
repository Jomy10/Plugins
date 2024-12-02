<div align="center">
  <h1>Plugins</h1>
  ❰
  <a href="EXAMPLES.md">examples</a>
  |
  <a href="https://swiftpackageindex.com/Jomy10/Plugins/master/documentation/plugins">documentation</a>
  ❱
</div><br/>
<div align="center">
  <a href="https://swiftpackageindex.com/Jomy10/Plugins"><img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FJomy10%2FPlugins%2Fbadge%3Ftype%3Dswift-versions"></img></a>
  <a href="https://swiftpackageindex.com/Jomy10/Plugins"><img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FJomy10%2FPlugins%2Fbadge%3Ftype%3Dplatforms"></img></a>
</div><br/>

A simple plugin framework for Swift applications.

Load dynamic libraries and call their functions dynamically.

## Example

**Plugin.swift**
```swift
@_cdecl("loadPlugin")
public func loadPlugin(_ data: UnsafeMutablePointer) -> Int32 {
  print("Plugin was loaded!")
  return 0
}

@_cdecl("somePluginFunction")
public func somePluginFunction() {
  print("Called some library function")
}
```

**Main.swift**
```swift
let plugin = Plugin(name: "Plugin", location: URL.currentDirectory())
// output: Plugin was loaded!
typealias SomePluginFunction = @convention(c) () -> ()
let pluginFn: PluginFunction<SomePluginFunction> = plugin.loadFunction(name: "somePluginFunction")!
pluginFn.function()
// output: Called some library function
```

We can compile the above **Plugin.swift** file with Swift Package Manager by defining
a library product for the Plugin target:

```swift
.library(
  name: "Plugin",
  type: .dynamic,
  targets: ["Plugin"]
)
```

More examples, see [EXAMPLES.md](EXAMPLES.md).

## Logging

The library also supports some basic logging using [swift-log](https://github.co/apple/swift-log).
