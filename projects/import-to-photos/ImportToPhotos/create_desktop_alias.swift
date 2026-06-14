import Foundation

guard CommandLine.arguments.count == 3 else {
    FileHandle.standardError.write(Data("usage: create_desktop_alias <target> <alias>\n".utf8))
    exit(64)
}

let targetURL = URL(fileURLWithPath: CommandLine.arguments[1]).standardizedFileURL
let aliasURL = URL(fileURLWithPath: CommandLine.arguments[2]).standardizedFileURL

let bookmark = try targetURL.bookmarkData(
    options: [.suitableForBookmarkFile],
    includingResourceValuesForKeys: nil,
    relativeTo: nil
)

try URL.writeBookmarkData(bookmark, to: aliasURL)
