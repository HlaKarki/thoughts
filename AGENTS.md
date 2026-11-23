# Thoughts

Thoughts is a native Mac app that keeps text and screenshots from any app as Markdown files in a folder you own.
The app, the `thoughts` command line tool and a Share extension all sit on one Swift package, `ThoughtsCore`.

## Commands

Run these before every commit.

- Comment check: `swift run --package-path Tools/CommentCheck comment-check .`
- Format: `git ls-files -z --cached --others --exclude-standard '*.swift' | xargs -0 xcrun swift-format format -i`, then the same list piped to `xargs -0 xcrun swift-format lint --strict`
- Core tests: `swift test --package-path Packages/ThoughtsCore`
- App build: `xcodegen generate && mkdir -p Thoughts.xcodeproj/project.xcworkspace/xcshareddata/swiftpm && cp Config/Package.resolved Thoughts.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/ && xcodebuild -project Thoughts.xcodeproj -scheme Thoughts -configuration Debug build`
- App tests: `xcodebuild test -project Thoughts.xcodeproj -scheme Thoughts -configuration Debug -destination 'platform=macOS'`

Copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig` to sign with your own team. Without it the app signs ad hoc.

## No comments

Code carries no comments of any kind: no file headers, no doc comments, no MARK lines, and none in scripts, YAML or xcconfig files. A comment is a claim nothing tests, so it goes stale without notice. Put the reason in the name, the structure or the commit message instead. CI rejects any comment. The one exception is `// swift-tools-version:` on line 1 of a `Package.swift`.

## Commits

One line, in the form `type: area; what changed`, for example `fix: index; rebuild after a folder move`. No body.

## Tests

Tests are few and deliberate, written with Swift Testing. Each one checks a rule the product depends on. Tests never touch the real pasteboard, the real thoughts folder or the real Application Support folder. Use temporary folders and private named pasteboards.
