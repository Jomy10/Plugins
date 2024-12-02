import Foundation
import Logging

#if canImport(Darwin)
import Darwin
let LIBEXT = "dylib"
#elseif os(Windows)
import ucrt
let LIBEXT = "dll"
#elseif canImport(Glibc)
import Glibc
let LIBEXT = "so"
#elseif canImport(Musl)
import Musl
let LIBEXT = "so"
#elseif canImport(WASILibc)
import WASILibc
let LIBEXT = "wasm"
#warning("WASI is probably not supported by the Plugins package")
#elseif canImport(Android)
import Android
let LIBEXT = "so"
#else
#error("Unsupported Platform")
#endif

/// A pliugin is a dynamic library that is loaded at runtime and exports
/// certain functions. These functions can be loaded using `loadFunction`
public final class Plugin {
  private static let logger = Logger(label: "be.jonaseveraert.Plugins")

  private typealias LoadPluginFunction = @convention(c) (UnsafeMutableRawPointer?) -> Int32
  private typealias UnloadPluginFunction = @convention(c) (UnsafeMutableRawPointer?) -> Void

  public let name: String
  private let handle: UnsafeMutableRawPointer
  private let unloadFn: UnloadPluginFunction?
  private let unloadData: UnsafeMutableRawPointer?

  public enum LoadError: Swift.Error {
    /// Error happened while loading the plugin
    case load(String)
    /// Error happened while loading the load function
    case loadInit(String)
    /// Error happened while loading the unload function
    case loadDeinit(String)
    /// Error happened while executing the load function and it returned with exit code `code`
    case loadExec(code: Int32)
  }

  /// Load a new plugin.
  //
  // A plugin is a dynamic library that exports some symbols
  //
  // The library is located at `location/lib\(name).\(ext)` where ext is `dylib` on macOS, `so` on Linux and `dll` on Windows
  public init(
    /// The plugin name (e.g. if the library is libplugin.dylib, then the plugin's name is "plugin")
    name: String,
    /// The location where the dynamic library is located
    location: URL,
    /// Data passed to the loadPlugin function of the plugin
    initData: UnsafeMutableRawPointer? = nil,
    /// Alternate name for the loadPlugin fuction. If nil, then no load function will be executed on the plugin
    initFunctionName: String? = "loadPlugin",
    /// Pass data to a function specified in the plugin for unloading the library
    deinitData: UnsafeMutableRawPointer? = nil,
    /// A function to unload the library, specified by the plugin
    deinitFunctionName: String? = nil
  ) throws /*LoadError*/ {
    self.name = name

    let libPath = location.appendingPathComponent("lib\(name).\(LIBEXT)")
    Self.logger.debug("Loading plugin \(name) at \(libPath.path)")
    guard let handle = libPath.path.withCString({ pathCStr in
      return dlopen(pathCStr, RTLD_LAZY)
    }) else {
      throw Self.LoadError.load(String(cString: dlerror()))
    }

    if let loadFnName = initFunctionName {
      let loadFn = try loadFnName.withCString { loadFnNameC in
        guard let loadFn = dlsym(handle, loadFnNameC) else {
          throw Self.LoadError.loadInit(String(cString: dlerror()))
        }
        return loadFn
      }
      let cloadFn = unsafeBitCast(loadFn, to: LoadPluginFunction.self)
      let ret = cloadFn(initData)
      if ret != 0 {
        throw Self.LoadError.loadExec(code: ret)
      }
    }

    if deinitFunctionName != nil || deinitData != nil {
      let unloadFnName = deinitFunctionName ?? "unloadPlugin"
      let unloadFn = try unloadFnName.withCString { unloadFnNameC in
        guard let unloadFn = dlsym(handle, unloadFnNameC) else {
          throw Self.LoadError.loadDeinit(String(cString: dlerror()))
        }
        return unloadFn
      }
      self.unloadFn = unsafeBitCast(unloadFn, to: UnloadPluginFunction.self)
    } else {
      self.unloadFn = nil
    }
    self.unloadData = deinitData

    self.handle = handle
  }

  /// Load a function with the specified name from the plugin
  ///
  /// # Function type
  /// The generic `FnType` has to be a function pointer type decorated with `@convention(c)`.
  /// It can only use types compatible with the C ABI (Ints, Pointers, ... but not classes for example).
  /// **Example**: `@convention(c) (Int32, UnsafeRawPointer) -> Int64`
  ///
  /// To pass swift types to these functions, one could use pointers.
  /// ```
  /// let str = "Hello world"
  /// withUnsafePointer(to: &str) { strptr in
  ///   pluginFunction.function(UnsafeRawPointer(strptr))
  /// }
  ///
  /// // In the plugin:
  /// @_silgen_name("MyPluginFunction")
  /// func myPluginFunction(_ strptr: UnsafeRawPointer) {
  ///   let str: UnsafePointer<String> = strptr.assumingMemoryBound(to: String.self)
  ///   print(str.pointee)
  /// }
  /// ```
  ///
  /// One needs to take extra care when passing values by pointers to make sure that
  /// the variables pointed to live long enough. For classes you might want look into
  /// increasing the reference count manually for example.
  ///
  /// # Returns
  /// A reference class holding the value of the function or nil if the function with
  /// the specified name doesn't exist
  public func loadFunction<FnType>(name functionName: String) -> PluginFunction<FnType>? {
    return functionName.withCString { nameCStr in
      guard let functionPtr = dlsym(self.handle, nameCStr) else {
        Self.logger.debug("Couldn't load plugin function \(functionName) for plugin \(self.name): \(String(cString: dlerror()))")
        return nil
      }

      return PluginFunction(parent: self, function: unsafeBitCast(functionPtr, to: FnType.self))
    }
  }

  deinit {
    if let unloadFn = self.unloadFn {
      unloadFn(self.unloadData)
    }
    if dlclose(self.handle) != 0 {
      Self.logger.error("\(String(cString: dlerror()))")
    }
  }
}

/// A reference to a function plugin. `FnType` is a function type decorated with `@convention(c)`.
/// Example: `@convention(c) (Int32, UnsafeRawPointer) -> UInt64`
public final class PluginFunction<FnType> {
  /// The function holds a reference to the parent plugin. This ensures that the Plugin
  /// won't be closed while a reference to a function still exists
  private let parentPlugin: Plugin

  /// The function that is stored in this reference. This function should not be stored outside
  /// of this `PluginFunction` object. Doing so might cause segmentation faults. This function
  /// variable is only valid as long as `PluginFunction` exists.
  public let function: FnType

  init(parent: Plugin, function: FnType) {
    self.parentPlugin = parent
    self.function = function
  }
}
