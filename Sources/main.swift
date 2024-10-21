import ConsoleKit
import Foundation
import Logging

let console = Terminal()
let argz = ProcessInfo.processInfo.arguments
// if argz.count > 1 && argz[0] == "x" {
// }
let input = CommandInput(arguments: argz)

var commands = Commands(enableAutocomplete: true)
commands.use(Compress(), as: "compress", isDefault: true)
commands.use(Compress(), as: "c", isDefault: true)
commands.use(Expand(), as: "extract", isDefault: true)
commands.use(Expand(), as: "x", isDefault: true)

do {
    let group = commands.group(help: "An example command-line application built with ConsoleKit")
    try console.run(group, input: input)
} catch let error {
    console.error("\(error)")
}
