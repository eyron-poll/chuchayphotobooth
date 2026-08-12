$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$port = 5173
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $port)
$listener.Start()
Write-Host "CHUCHAY PHOTOBOOTH running at http://localhost:$port/"

$contentTypes = @{
  ".html" = "text/html; charset=utf-8"
  ".css" = "text/css; charset=utf-8"
  ".js" = "application/javascript; charset=utf-8"
  ".png" = "image/png"
  ".jpg" = "image/jpeg"
  ".jpeg" = "image/jpeg"
  ".svg" = "image/svg+xml"
  ".mp3" = "audio/mpeg"
}

try {
  while ($true) {
    $client = $listener.AcceptTcpClient()
    try {
      $stream = $client.GetStream()
      $reader = [System.IO.StreamReader]::new($stream, [Text.Encoding]::ASCII, $false, 1024, $true)
      $requestLine = $reader.ReadLine()
      while ($reader.ReadLine()) {}

      $path = "index.html"
      if ($requestLine -match "^GET\s+([^\s?]+)") {
        $path = [Uri]::UnescapeDataString($matches[1].TrimStart("/"))
        if ([string]::IsNullOrWhiteSpace($path)) {
          $path = "index.html"
        }
      }

      $target = [System.IO.Path]::GetFullPath((Join-Path $root $path))
      $status = "200 OK"
      $bytes = $null
      $contentType = "application/octet-stream"

      if (-not $target.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $target -PathType Leaf)) {
        $status = "404 Not Found"
        $contentType = "text/plain; charset=utf-8"
        $bytes = [Text.Encoding]::UTF8.GetBytes("Not found")
      } else {
        $extension = [System.IO.Path]::GetExtension($target).ToLowerInvariant()
        if ($contentTypes.ContainsKey($extension)) {
          $contentType = $contentTypes[$extension]
        }
        $bytes = [System.IO.File]::ReadAllBytes($target)
      }

      $headers = "HTTP/1.1 $status`r`nContent-Type: $contentType`r`nContent-Length: $($bytes.Length)`r`nConnection: close`r`n`r`n"
      $headerBytes = [Text.Encoding]::ASCII.GetBytes($headers)
      $stream.Write($headerBytes, 0, $headerBytes.Length)
      $stream.Write($bytes, 0, $bytes.Length)
      $stream.Flush()
    } finally {
      $client.Close()
    }
  }
} finally {
  $listener.Stop()
}
