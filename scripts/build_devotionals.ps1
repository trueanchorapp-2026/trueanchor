# Regenerates supabase/seed/devotionals_seed.sql from content/devotionals/*.json.
#
# The generated file is checked in and pasted into the Supabase SQL Editor, the
# same way every migration in this repo is applied. Nothing is written if any
# devotional fails validation -- the script prints every problem and exits 1.

$ErrorActionPreference = 'Stop'

$flutterBin = 'C:\Users\Wuxia\flutter_windows_3.44.7-stable\flutter\bin'
if (Test-Path $flutterBin) { $env:Path = "$env:Path;$flutterBin" }

Push-Location (Split-Path $PSScriptRoot -Parent)
try {
    dart run tool/build_devotional_seed.dart
}
finally {
    Pop-Location
}
