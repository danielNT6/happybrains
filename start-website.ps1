# Serves this folder at http://localhost:<port>/ and opens it in your browser.
# Keep the window open while you look at the site; close it to stop.
$ErrorActionPreference = 'Stop'
$root = [System.IO.Path]::GetFullPath($PSScriptRoot)
$sep = [string][System.IO.Path]::DirectorySeparatorChar
$types = @{
  '.html' = 'text/html; charset=utf-8'
  '.htm' = 'text/html; charset=utf-8'
  '.css' = 'text/css; charset=utf-8'
  '.js' = 'text/javascript; charset=utf-8'
  '.mjs' = 'text/javascript; charset=utf-8'
  '.json' = 'application/json'
  '.map' = 'application/json'
  '.framercms' = 'application/octet-stream'
  '.xml' = 'application/xml'
  '.txt' = 'text/plain; charset=utf-8'
  '.md' = 'text/plain; charset=utf-8'
  '.svg' = 'image/svg+xml'
  '.png' = 'image/png'
  '.jpg' = 'image/jpeg'
  '.jpeg' = 'image/jpeg'
  '.gif' = 'image/gif'
  '.webp' = 'image/webp'
  '.avif' = 'image/avif'
  '.ico' = 'image/x-icon'
  '.woff' = 'font/woff'
  '.woff2' = 'font/woff2'
  '.ttf' = 'font/ttf'
  '.otf' = 'font/otf'
  '.mp4' = 'video/mp4'
  '.webm' = 'video/webm'
  '.mp3' = 'audio/mpeg'
  '.wav' = 'audio/wav'
  '.ogg' = 'audio/ogg'
  '.pdf' = 'application/pdf'
  '.wasm' = 'application/wasm'
  '.glb' = 'model/gltf-binary'
  '.gltf' = 'model/gltf+json'
  '.lottie' = 'application/zip'
  '.webmanifest' = 'application/manifest+json'
}

function Resolve-SiteRequest([string]$rawPath) {
  $path = [System.Uri]::UnescapeDataString(($rawPath -split '[?#]')[0])
  if (-not $path.StartsWith('/')) { $path = '/' + $path }
  $relative = $path.TrimStart('/').Replace('/', $sep)
  $full = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($root, $relative))
  if (($full -ne $root) -and (-not $full.StartsWith($root.TrimEnd($sep) + $sep, [System.StringComparison]::OrdinalIgnoreCase))) {
    return @{ Status = 403 }
  }
  if ([System.IO.Directory]::Exists($full)) {
    if (-not $path.EndsWith('/')) { return @{ Status = 301; Location = ($rawPath -split '[?#]')[0] + '/' } }
    $full = [System.IO.Path]::Combine($full, 'index.html')
  }
  if ((-not [System.IO.File]::Exists($full)) -and [System.IO.File]::Exists($full + '.html')) { $full = $full + '.html' }
  if (-not [System.IO.File]::Exists($full)) {
    $notFound = [System.IO.Path]::Combine($root, '404.html')
    if ([System.IO.File]::Exists($notFound)) { return @{ Status = 404; File = $notFound } }
    return @{ Status = 404 }
  }
  return @{ Status = 200; File = $full }
}

function Get-ContentType([string]$file) {
  $type = $types[[System.IO.Path]::GetExtension($file).ToLowerInvariant()]
  if (-not $type) { $type = 'application/octet-stream' }
  return $type
}

$listener = $null
$port = 0
if (-not $env:NCE_FORCE_SOCKET_SERVER) {
  foreach ($candidate in 8080..8099) {
    $attempt = New-Object System.Net.HttpListener
    $attempt.Prefixes.Add('http://localhost:' + $candidate + '/')
    try { $attempt.Start(); $listener = $attempt; $port = $candidate; break } catch { $attempt.Close() }
  }
}

if ($listener) {
  $url = 'http://localhost:' + $port + '/'
  Write-Host ('Your website is running at ' + $url)
  Write-Host 'Keep this window open while you look at it. Close it to stop.'
  if (-not $env:NCE_NO_OPEN) { Start-Process $url }
  while ($listener.IsListening) {
    $context = $listener.GetContext()
    $response = $context.Response
    try {
      $result = Resolve-SiteRequest $context.Request.Url.AbsolutePath
      $response.StatusCode = $result.Status
      $response.Headers.Add('Cache-Control', 'no-cache')
      if ($result.Status -eq 301) {
        $response.RedirectLocation = $result.Location
      } elseif ($result.File) {
        $bytes = [System.IO.File]::ReadAllBytes($result.File)
        $response.ContentType = Get-ContentType $result.File
        $response.ContentLength64 = $bytes.Length
        if ($context.Request.HttpMethod -ne 'HEAD') { $response.OutputStream.Write($bytes, 0, $bytes.Length) }
      } else {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes('Not found')
        $response.ContentType = 'text/plain; charset=utf-8'
        $response.ContentLength64 = $bytes.Length
        $response.OutputStream.Write($bytes, 0, $bytes.Length)
      }
    } catch {
      try { $response.StatusCode = 500 } catch { }
    } finally {
      try { $response.Close() } catch { }
    }
  }
  exit 0
}

# HttpListener refused (no free port, or this account may not use it): a
# plain socket server on 127.0.0.1, one request per connection.
$server = $null
foreach ($candidate in 8080..8099) {
  try {
    $attempt = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $candidate)
    $attempt.Start(); $server = $attempt; $port = $candidate; break
  } catch { }
}
if (-not $server) { Write-Host 'No free port between 8080 and 8099.'; exit 1 }
$url = 'http://127.0.0.1:' + $port + '/'
Write-Host ('Your website is running at ' + $url)
Write-Host 'Keep this window open while you look at it. Close it to stop.'
if (-not $env:NCE_NO_OPEN) { Start-Process $url }
$crlf = [string][char]13 + [string][char]10
while ($true) {
  $client = $server.AcceptTcpClient()
  try {
    $client.ReceiveTimeout = 3000
    $stream = $client.GetStream()
    $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::ASCII, $false, 8192, $true)
    $requestLine = $reader.ReadLine()
    while ($true) { $line = $reader.ReadLine(); if (($line -eq $null) -or ($line -eq '')) { break } }
    if (-not $requestLine) { continue }
    $parts = $requestLine.Split(' ')
    if ($parts.Length -lt 2) { continue }
    $result = Resolve-SiteRequest $parts[1]
    $extra = ''
    $body = New-Object byte[] 0
    $type = 'text/plain; charset=utf-8'
    if ($result.Status -eq 301) { $extra = 'Location: ' + $result.Location + $crlf }
    elseif ($result.File) { $body = [System.IO.File]::ReadAllBytes($result.File); $type = Get-ContentType $result.File }
    else { $body = [System.Text.Encoding]::UTF8.GetBytes('Not found') }
    $reasons = @{ 200 = 'OK'; 301 = 'Moved Permanently'; 403 = 'Forbidden'; 404 = 'Not Found' }
    $head = 'HTTP/1.1 ' + $result.Status + ' ' + $reasons[[int]$result.Status] + $crlf + 'Content-Type: ' + $type + $crlf + 'Content-Length: ' + $body.Length + $crlf + 'Cache-Control: no-cache' + $crlf + 'Connection: close' + $crlf + $extra + $crlf
    $headBytes = [System.Text.Encoding]::ASCII.GetBytes($head)
    $stream.Write($headBytes, 0, $headBytes.Length)
    if (($parts[0] -ne 'HEAD') -and ($body.Length -gt 0)) { $stream.Write($body, 0, $body.Length) }
    $stream.Flush()
  } catch {
  } finally {
    $client.Close()
  }
}
