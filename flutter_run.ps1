param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$FlutterArgs
)

$flutterRoot = "c:\Users\rahma\OneDrive\Documents\Unicorn App\flutter"
$env:APPDATA = "c:\Users\rahma\OneDrive\Documents\Unicorn App\.appdata"
$env:LOCALAPPDATA = "c:\Users\rahma\OneDrive\Documents\Unicorn App\.localappdata"
$env:PUB_CACHE = "c:\Users\rahma\OneDrive\Documents\Unicorn App\.pub-cache"
$env:FLUTTER_SUPPRESS_ANALYTICS = "true"

$dart = "$flutterRoot\bin\cache\dart-sdk\bin\dart.exe"
$snapshot = "$flutterRoot\bin\cache\flutter_tools.snapshot"
$pkg = "$flutterRoot\packages\flutter_tools\.dart_tool\package_config.json"

& $dart --packages=$pkg --no-enable-mirrors $snapshot $FlutterArgs
exit $LASTEXITCODE
