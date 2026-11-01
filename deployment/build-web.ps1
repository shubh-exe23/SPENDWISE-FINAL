$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
Push-Location (Join-Path $repo 'SpendWise')
try {
    flutter build web --release --dart-define=API_BASE_URL=/api
    if ($LASTEXITCODE -ne 0) { throw 'Flutter build failed' }
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot '_headers') -Destination 'build/web/_headers'
} finally { Pop-Location }
