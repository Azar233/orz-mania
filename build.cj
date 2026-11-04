import std.process.*

// cjpm run/build prepares the bundled native libraries without invoking cjpm recursively.
main(): Int64 {
    let args = Process.current.arguments
    if (args.size == 0) {
        return 0
    }
    match (args[0]) {
        case "post-build" =>
            let child = launch("powershell.exe",
                ["-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", "tools/finalize-build.ps1"])
            return child.wait()
        case "pre-run" | "pre-build" =>
            let child = launch("powershell.exe",
                ["-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", "tools/prepare-runtime.ps1"])
            return child.wait()
        case _ => return 0
    }
}
