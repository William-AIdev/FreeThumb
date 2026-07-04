# Update manifest

FreeThumb checks an HTTPS JSON document. The built-in release source is:

`https://raw.githubusercontent.com/William-AIdev/FreeThumb/main/update-manifest.json`

Users can replace this URL in Settings when testing another release channel.

```json
{
  "version": "0.1.0",
  "downloadURL": "https://github.com/William-AIdev/FreeThumb/releases/download/v0.1.0/FreeThumb-macOS-0.1.0.zip"
}
```

`version` is compared numerically with `CFBundleShortVersionString`. FreeThumb
only reports and opens the download; it does not silently install software.
