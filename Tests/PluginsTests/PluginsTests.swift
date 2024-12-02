import Foundation
import XCTest
import Logging
@testable import Plugins

final class PluginsTests: XCTestCase {
  typealias PluginExportedFunction = @convention(c) (UnsafeMutableRawPointer) -> Void

  static let pluginCode = """
  @_cdecl("loadPlugin")
  public func loadPlugin(_ data: UnsafeMutableRawPointer) -> Int32 {
    let intptr = data.assumingMemoryBound(to: Int.self)
    intptr.pointee += 1
    return 0
  }

  @_cdecl("pluginExportedFunction")
  public func fn(_ data: UnsafeMutableRawPointer) {
    let intptr = data.assumingMemoryBound(to: Int.self)
    intptr.pointee += 1
  }

  @_cdecl("unloadPlugin")
  public func unloadPlugin(_ data: UnsafeMutableRawPointer) {
    let intptr = data.assumingMemoryBound(to: Int.self)
    intptr.pointee -= 1
  }
  """

  static let tempdir: URL = FileManager.default.temporaryDirectory
  static let pluginSourceFile: URL = FileManager.default.temporaryDirectory
    .appendingPathComponent("testPlugin.swift")

  override class func setUp() {
    LoggingSystem.bootstrap { loggerId in
      var handler = StreamLogHandler.standardError(label: loggerId)
      handler.logLevel = .trace
      return handler
    }

    try! pluginCode.write(to: Self.pluginSourceFile, atomically: true, encoding: .utf8)

    let compileTask = Process()
    let pipe = Pipe()

    compileTask.standardOutput = pipe
    compileTask.standardError = pipe
    compileTask.arguments = [
      "-c",
      "swiftc \(Self.pluginSourceFile.path) -parse-as-library -emit-library",
    ]
    compileTask.currentDirectoryURL = Self.tempdir
    compileTask.executableURL = URL(fileURLWithPath: "/bin/sh")

    try! compileTask.run()
    compileTask.waitUntilExit()
    if compileTask.terminationStatus != 0 {
      fatalError("Couldn't compile example code")
    }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    print(String(data: data, encoding: .utf8)!)
  }

  /// Basic usage:
  /// - Create a plugin with load and unload data
  /// - Call a function in the plugin
  func testPlugin() throws {
    var counter: Int = 0
    do {
      let plugin = try withUnsafeMutablePointer(to: &counter) { (ptr: UnsafeMutablePointer<Int>) in
        let rawPtr = UnsafeMutableRawPointer(ptr)
        return try Plugin(name: "testPlugin", location: Self.tempdir, initData: rawPtr, deinitData: rawPtr)
      }
      XCTAssertEqual(counter, 1)
      let fn: PluginFunction<PluginExportedFunction> = plugin.loadFunction(name: "pluginExportedFunction")!
      withUnsafeMutablePointer(to: &counter) { (ptr) in
        fn.function(UnsafeMutableRawPointer(ptr))
      }
      XCTAssertEqual(counter, 2)
    } // plugin gets unloaded here

    XCTAssertEqual(counter, 1)
  }

  /// Assure that when a plugin is no longer in scope, but a function still exists,
  /// the plugin will not be unloaded
  func testFunctionReference() throws {
    var counter: Int = 0
    do {
      let fn: PluginFunction<PluginExportedFunction>
      do {
        let plugin = try withUnsafeMutablePointer(to: &counter) { (ptr: UnsafeMutablePointer<Int>) in
          let rawPtr = UnsafeMutableRawPointer(ptr)
          return try Plugin(name: "testPlugin", location: Self.tempdir, initData: rawPtr, deinitData: rawPtr)
        }
        XCTAssertEqual(counter, 1)

        fn = plugin.loadFunction(name: "pluginExportedFunction")!
      } // plugin not dropped yet becase there is still a reference
      XCTAssertEqual(counter, 1)

      withUnsafeMutablePointer(to: &counter) { (ptr) in
        fn.function(UnsafeMutableRawPointer(ptr))
      }
      XCTAssertEqual(counter, 2)
    } // fn dropped here and plugin dropped here
    XCTAssertEqual(counter, 1)
  }
}
