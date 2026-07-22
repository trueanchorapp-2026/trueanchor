# Launches TrueAnchor against the CBCCS Supabase project.
#
# The publishable key is safe to keep here: it is designed for client-side use
# and Postgres RLS is what actually protects the data. Never put a
# service_role / sb_secret_* key in this file -- a web build ships its source
# to every visitor.

param(
    [int]$Port = 5000,
    [string]$Device = 'chrome'
)

$ErrorActionPreference = 'Stop'

$flutterBin = 'C:\Users\Wuxia\flutter_windows_3.44.7-stable\flutter\bin'
if (Test-Path $flutterBin) { $env:Path = "$env:Path;$flutterBin" }

$supabaseUrl = 'https://vilevuoyzfkzcybgoixd.supabase.co'
$publishableKey = 'sb_publishable_UcpyijWXcIs0tMOofu_UzA_2JRXZqU-'

Push-Location (Split-Path $PSScriptRoot -Parent)
try {
    flutter run -d $Device --web-port=$Port `
        --dart-define=SUPABASE_URL=$supabaseUrl `
        --dart-define=SUPABASE_PUBLISHABLE_KEY=$publishableKey
}
finally {
    Pop-Location
}
