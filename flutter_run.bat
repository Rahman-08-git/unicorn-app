@ECHO OFF
SET "flutterRoot=C:\Users\rahma\OneDrive\Documents\UNICOR~1\flutter"
SET "APPDATA=C:\Users\rahma\OneDrive\Documents\UNICOR~1\.appdata"
SET "LOCALAPPDATA=C:\Users\rahma\OneDrive\Documents\UNICOR~1\.localappdata"
SET "PUB_CACHE=C:\Users\rahma\OneDrive\Documents\UNICOR~1\.pub-cache"
SET "FLUTTER_SUPPRESS_ANALYTICS=true"

SET "dart=%flutterRoot%\bin\cache\dart-sdk\bin\dart.exe"
SET "snapshot=%flutterRoot%\bin\cache\flutter_tools.snapshot"
SET "pkg=%flutterRoot%\packages\flutter_tools\.dart_tool\package_config.json"

"%dart%" --packages="%pkg%" --no-enable-mirrors "%snapshot%" %*
EXIT /B %ERRORLEVEL%
