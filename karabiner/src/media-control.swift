import AppKit
import ApplicationServices
import CoreFoundation
import Darwin
import Foundation

let appPath = "/Users/sam/.config/shared/karabiner/.bin/FnMediaControl.app"
let socketPath = "/tmp/karabiner-fn-media-control.sock"
let stateFile = "/tmp/karabiner-fn-media-was-playing"
let logFile = "/tmp/karabiner-fn-media-control.log"

struct MediaRemote {
  let isPlaying: () -> Bool
  let sendCommand: (Int) -> Bool
}

func loadMediaRemote() -> MediaRemote? {
  let frameworkPath = "/System/Library/PrivateFrameworks/MediaRemote.framework"
  guard
    let bundle = CFBundleCreate(kCFAllocatorDefault, URL(fileURLWithPath: frameworkPath) as CFURL),
    let getPlayingPointer = CFBundleGetFunctionPointerForName(
      bundle,
      "MRMediaRemoteGetNowPlayingApplicationIsPlaying" as CFString
    ),
    let getInfoPointer = CFBundleGetFunctionPointerForName(
      bundle,
      "MRMediaRemoteGetNowPlayingInfo" as CFString
    ),
    let registerPointer = CFBundleGetFunctionPointerForName(
      bundle,
      "MRMediaRemoteRegisterForNowPlayingNotifications" as CFString
    ),
    let sendCommandPointer = CFBundleGetFunctionPointerForName(
      bundle,
      "MRMediaRemoteSendCommand" as CFString
    )
  else {
    log("mediaremote load failed")
    return nil
  }

  typealias GetNowPlayingApplicationIsPlaying = @convention(c) (
    DispatchQueue,
    @escaping (Bool) -> Void
  ) -> Void
  typealias GetNowPlayingInfo = @convention(c) (
    DispatchQueue,
    @escaping ([String: Any]) -> Void
  ) -> Void
  typealias RegisterForNowPlayingNotifications = @convention(c) (DispatchQueue) -> Void
  typealias SendCommand = @convention(c) (Int, AnyObject?) -> Bool
  let getNowPlayingApplicationIsPlaying = unsafeBitCast(
    getPlayingPointer,
    to: GetNowPlayingApplicationIsPlaying.self
  )
  let getNowPlayingInfo = unsafeBitCast(getInfoPointer, to: GetNowPlayingInfo.self)
  let registerForNowPlayingNotifications = unsafeBitCast(
    registerPointer,
    to: RegisterForNowPlayingNotifications.self
  )
  let sendCommand = unsafeBitCast(sendCommandPointer, to: SendCommand.self)

  registerForNowPlayingNotifications(DispatchQueue.main)

  return MediaRemote(
    isPlaying: {
      var applicationResult = false
      var applicationDidReturn = false

      getNowPlayingApplicationIsPlaying(DispatchQueue.main) { playing in
        applicationResult = playing
        applicationDidReturn = true
      }

      let deadline = Date().addingTimeInterval(0.2)
      while !applicationDidReturn && Date() < deadline {
        RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.01))
      }

      if !applicationDidReturn {
        log("mediaremote isPlaying timed out")
      }

      var infoResult: [String: Any] = [:]
      var infoDidReturn = false

      getNowPlayingInfo(DispatchQueue.main) { info in
        infoResult = info
        infoDidReturn = true
      }

      let infoDeadline = Date().addingTimeInterval(0.2)
      while !infoDidReturn && Date() < infoDeadline {
        RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.01))
      }

      let rawRate = infoResult["kMRMediaRemoteNowPlayingInfoPlaybackRate"]
      let rate: Double? = if let value = rawRate as? Double {
        value
      } else if let value = rawRate as? Float {
        Double(value)
      } else if let value = rawRate as? Int {
        Double(value)
      } else {
        nil
      }
      let infoPlaying = (rate ?? 0) > 0
      let title = infoResult["kMRMediaRemoteNowPlayingInfoTitle"] ?? "unknown"
      let result = applicationResult || infoPlaying
      log("mediaremote applicationIsPlaying=\(applicationResult) infoIsPlaying=\(infoPlaying) rate=\(String(describing: rate)) title=\(title)")
      return result
    },
    sendCommand: { command in
      sendCommand(command, nil)
    }
  )
}

let mediaRemote = loadMediaRemote()

func log(_ message: String) {
  let timestamp = ISO8601DateFormatter().string(from: Date())
  let line = "\(timestamp) \(message)\n"
  guard let data = line.data(using: .utf8) else { return }

  if FileManager.default.fileExists(atPath: logFile),
    let handle = try? FileHandle(forWritingTo: URL(fileURLWithPath: logFile))
  {
    handle.seekToEndOfFile()
    handle.write(data)
    try? handle.close()
  } else {
    try? data.write(to: URL(fileURLWithPath: logFile))
  }
}

func sendPause() {
  if let mediaRemote {
    let sent = mediaRemote.sendCommand(1) // MRMediaRemoteCommandPause
    log("mediaremote pause sent=\(sent)")
  }
}

func sendPlay() {
  if let mediaRemote {
    let sent = mediaRemote.sendCommand(0) // MRMediaRemoteCommandPlay
    log("mediaremote play sent=\(sent)")
  }
}

func writeState(_ apps: [String]) {
  try? apps.joined(separator: "\n").write(
    toFile: stateFile,
    atomically: true,
    encoding: .utf8
  )
}

func clearState() {
  try? FileManager.default.removeItem(atPath: stateFile)
}

func readState() -> [String] {
  guard let value = try? String(contentsOfFile: stateFile, encoding: .utf8) else {
    return []
  }

  return value.split(separator: "\n").map(String.init)
}

func handle(_ command: String) -> String {
  switch command {
  case "pause-if-playing":
    clearState()
    sendPause()
    writeState(["media"])
    return "ok"

  case "resume-if-paused":
    let pausedApps = readState()
    log("resume-if-paused pausedApps=\(pausedApps)")
    if !pausedApps.isEmpty {
      sendPlay()
      clearState()
    }
    return "ok"

  case "force-toggle":
    sendPause()
    log("force-toggle treated as pause")
    return "ok"

  case "mediaremote-pause":
    sendPause()
    return "ok"

  case "mediaremote-play":
    sendPlay()
    return "ok"

  default:
    log("unknown command=\(command)")
    return "unknown command"
  }
}

func withSocketAddress<T>(_ path: String, _ body: (UnsafePointer<sockaddr>, socklen_t) -> T) -> T {
  var address = sockaddr_un()
  address.sun_family = sa_family_t(AF_UNIX)
  let maxPathLength = MemoryLayout.size(ofValue: address.sun_path) - 1

  _ = withUnsafeMutablePointer(to: &address.sun_path.0) { pointer in
    path.withCString { source in
      strncpy(pointer, source, maxPathLength)
    }
  }

  return withUnsafePointer(to: &address) { pointer in
    pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
      body(socketAddress, socklen_t(MemoryLayout<sockaddr_un>.size))
    }
  }
}

func runDaemon() -> Never {
  unlink(socketPath)

  let server = socket(AF_UNIX, SOCK_STREAM, 0)
  guard server >= 0 else {
    log("socket failed errno=\(errno)")
    exit(1)
  }

  let bindResult = withSocketAddress(socketPath) { address, length in
    bind(server, address, length)
  }
  guard bindResult == 0 else {
    log("bind failed errno=\(errno)")
    exit(1)
  }

  chmod(socketPath, 0o600)
  guard listen(server, 8) == 0 else {
    log("listen failed errno=\(errno)")
    exit(1)
  }

  log("daemon started pid=\(getpid())")

  while true {
    let client = accept(server, nil, nil)
    if client < 0 {
      log("accept failed errno=\(errno)")
      continue
    }

    var buffer = [UInt8](repeating: 0, count: 1024)
    let count = read(client, &buffer, buffer.count - 1)
    let command = count > 0
      ? String(decoding: buffer.prefix(count).filter { $0 != 0 && $0 != 10 }, as: UTF8.self)
      : ""
    let response = handle(command) + "\n"
    response.withCString { pointer in
      _ = write(client, pointer, strlen(pointer))
    }
    close(client)
  }
}

func startDaemon() {
  let process = Process()
  process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
  process.arguments = ["-gj", appPath]
  do {
    try process.run()
    process.waitUntilExit()
    log("open daemon exit=\(process.terminationStatus)")
  } catch {
    log("open daemon error=\(error)")
  }
}

func sendToDaemon(_ command: String) -> Bool {
  let client = socket(AF_UNIX, SOCK_STREAM, 0)
  guard client >= 0 else {
    log("client socket failed errno=\(errno)")
    return false
  }
  defer { close(client) }

  let connectResult = withSocketAddress(socketPath) { address, length in
    connect(client, address, length)
  }
  guard connectResult == 0 else {
    log("connect failed errno=\(errno)")
    return false
  }

  command.withCString { pointer in
    _ = write(client, pointer, strlen(pointer))
  }

  var buffer = [UInt8](repeating: 0, count: 1024)
  let count = read(client, &buffer, buffer.count - 1)
  if count > 0 {
    let response = String(decoding: buffer.prefix(count), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    log("daemon response command=\(command) response=\(response)")
  }

  return true
}

let command = CommandLine.arguments.dropFirst().first

if command == nil || command == "--daemon" {
  runDaemon()
}

if command == "start-daemon" {
  startDaemon()
  exit(0)
}

if let command {
  if !sendToDaemon(command) {
    startDaemon()
    Thread.sleep(forTimeInterval: 0.5)
    if !sendToDaemon(command) {
      log("falling back to direct handling command=\(command)")
      print(handle(command))
    }
  }
} else {
  fputs("usage: media-control start-daemon|pause-if-playing|resume-if-paused|force-toggle\n", stderr)
  exit(64)
}
