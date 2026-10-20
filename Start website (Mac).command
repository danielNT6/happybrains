#!/bin/bash
# Serves this folder at http://127.0.0.1:<port>/ and opens it in your browser.
# Keep the window open while you look at the site; close it (or press Ctrl+C) to stop.
# Linux: run  bash "Start website (Mac).command"  in this folder.
cd "$(dirname "$0")" || exit 1

PORT=""
for candidate in $(seq 8080 8099); do
  if ! (echo > "/dev/tcp/127.0.0.1/$candidate") >/dev/null 2>&1; then PORT=$candidate; break; fi
done
if [ -z "$PORT" ]; then echo "No free port between 8080 and 8099."; read -r -p "Press Enter to close."; exit 1; fi
URL="http://127.0.0.1:$PORT/"

open_browser() {
  sleep 1
  if [ -n "$NCE_NO_OPEN" ]; then return; fi
  if command -v open >/dev/null 2>&1; then open "$URL"; elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$URL"; fi
}

echo "Your website is running at $URL"
echo "Keep this window open while you look at it. Close it (or press Ctrl+C) to stop."

if command -v perl >/dev/null 2>&1; then
  open_browser &
  exec perl - "$PORT" <<'PERL'
use strict;
use warnings;
use IO::Socket::INET;
use Cwd qw(abs_path);
my $port = shift;
my $root = abs_path(".");
my %types = (
  "html" => "text/html; charset=utf-8",
  "htm" => "text/html; charset=utf-8",
  "css" => "text/css; charset=utf-8",
  "js" => "text/javascript; charset=utf-8",
  "mjs" => "text/javascript; charset=utf-8",
  "json" => "application/json",
  "map" => "application/json",
  "framercms" => "application/octet-stream",
  "xml" => "application/xml",
  "txt" => "text/plain; charset=utf-8",
  "md" => "text/plain; charset=utf-8",
  "svg" => "image/svg+xml",
  "png" => "image/png",
  "jpg" => "image/jpeg",
  "jpeg" => "image/jpeg",
  "gif" => "image/gif",
  "webp" => "image/webp",
  "avif" => "image/avif",
  "ico" => "image/x-icon",
  "woff" => "font/woff",
  "woff2" => "font/woff2",
  "ttf" => "font/ttf",
  "otf" => "font/otf",
  "mp4" => "video/mp4",
  "webm" => "video/webm",
  "mp3" => "audio/mpeg",
  "wav" => "audio/wav",
  "ogg" => "audio/ogg",
  "pdf" => "application/pdf",
  "wasm" => "application/wasm",
  "glb" => "model/gltf-binary",
  "gltf" => "model/gltf+json",
  "lottie" => "application/zip",
  "webmanifest" => "application/manifest+json",
);
my $server = IO::Socket::INET->new(LocalAddr => "127.0.0.1", LocalPort => $port, Listen => 64, ReuseAddr => 1)
  or die "Could not listen on port $port: $!\n";
$SIG{CHLD} = "IGNORE";
while (my $client = $server->accept) {
  my $pid = fork();
  if (!defined $pid) { close $client; next; }
  if ($pid) { close $client; next; }
  close $server;
  handle($client);
  close $client;
  exit 0;
}
sub reply {
  my ($client, $status, $reason, $type, $body, $extra, $head_only) = @_;
  $extra = "" unless defined $extra;
  print $client "HTTP/1.1 $status $reason\r\nContent-Type: $type\r\nContent-Length: " . length($body)
    . "\r\nCache-Control: no-cache\r\nConnection: close\r\n$extra\r\n";
  print $client $body unless $head_only;
}
sub file_body {
  my ($file) = @_;
  open(my $fh, "<:raw", $file) or return undef;
  local $/;
  my $body = <$fh>;
  close $fh;
  return defined $body ? $body : "";
}
sub content_type {
  my ($file) = @_;
  my ($ext) = $file =~ /\.([^.\/]+)$/;
  return $types{lc(defined $ext ? $ext : "")} || "application/octet-stream";
}
sub handle {
  my ($client) = @_;
  binmode $client;
  my $request = <$client>;
  return unless defined $request;
  while (my $header = <$client>) { last if $header =~ /^\r?\n$/; }
  my ($method, $target) = split / /, $request;
  return unless defined $target;
  my $head_only = $method eq "HEAD";
  (my $raw = $target) =~ s/[?#].*//s;
  (my $path = $raw) =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/ge;
  $path = "/$path" unless $path =~ m{^/};
  if ($path =~ m{(^|/)\.\.(/|$)}) { reply($client, 403, "Forbidden", "text/plain", "Forbidden", "", $head_only); return; }
  my $file = $root . $path;
  if (-d $file) {
    if ($path !~ m{/$}) { reply($client, 301, "Moved Permanently", "text/plain", "", "Location: $raw/\r\n", $head_only); return; }
    $file .= "index.html";
  }
  $file .= ".html" if !-f $file && -f "$file.html";
  if (!-f $file) {
    my $not_found = "$root/404.html";
    if (-f $not_found) { reply($client, 404, "Not Found", "text/html; charset=utf-8", file_body($not_found), "", $head_only); }
    else { reply($client, 404, "Not Found", "text/plain", "Not found", "", $head_only); }
    return;
  }
  my $body = file_body($file);
  if (!defined $body) { reply($client, 403, "Forbidden", "text/plain", "Forbidden", "", $head_only); return; }
  reply($client, 200, "OK", content_type($file), $body, "", $head_only);
}
PERL
fi

if command -v python3 >/dev/null 2>&1 && { [ "$(command -v python3)" != "/usr/bin/python3" ] || xcode-select -p >/dev/null 2>&1 || [ "$(uname)" != "Darwin" ]; }; then
  open_browser &
  exec python3 -m http.server "$PORT" --bind 127.0.0.1
fi

if command -v npx >/dev/null 2>&1; then
  open_browser &
  exec npx --yes serve -l "$PORT" .
fi

echo "No web server is available on this computer (Perl, Python or Node)."
echo "See https://www.nocodeexport.com/en/blog/run-exported-site-locally"
read -r -p "Press Enter to close."
