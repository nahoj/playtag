# AGENTS.md

Guidance for AI coding agents working in this repository.

## Project overview

Playtag embeds playback parameters (volume, start/stop times, aspect ratio, etc.) in media file tags, and provides a VLC wrapper and an mpv script that honor them.

The project is a Ruby rewrite of the original Python script (`spec/playtag-python`).

## Coding rules

- *Never* corrupt files or make them unreadable. We rely mostly on TagLib for this, but be careful not to do anything dangerous.
  - When an operation fails, playtag must crash rather than try a degraded operation.
- Stay compatible with files tagged by playtag-python: read and write Playtag tags the same way it does.
- We use TagLib 2.x. Check the [taglib-ruby API doc](https://rubydoc.info/gems/taglib-ruby) often.
- KISS. No fallbacks, hacks, workarounds, or backward compatibility with anything other than playtag-python. Find the right way to do things and stick with it.
- Print error messages on *stderr*, not *stdout*.

## Architecture

- `bin/playtag`: CLI entry point (`read`, `write`, `clear`, `edit`, `vlc`; see `playtag --help`).
- `lib/playtag/`: library code.
  - `cli.rb`, `editor.rb`, `vlc.rb`: commands.
  - `tag.rb`, `tag/`: per-format tag handlers. Most formats go through TagLib (`id3v2_tag.rb`, `mp4_tag.rb`, `xiph_tag.rb`). MKV/WebM goes through `mkvextract`/`mkvpropedit` (`mkv_tag.rb`).
- `mpv/playtag.lua`, `mpv/playtag_lib.lua`: mpv script that reads tags and applies settings through the mpv API, without the wrapper.
- `spec/`: RSpec + Aruba tests. Fixtures are in `spec/fixtures/`.
- `tools/`: ad-hoc debugging scripts.

## Tag format

A tag is a semicolon-separated list of parameters that starts with a version, e.g. `v1; t=0:26; vol=+3dB`. The full spec is in `README.md`. Parameters:

- `t`: time range (start-stop, start only, or stop only)
- `vol`: volume adjustment (dB, volt gain, sone gain)
- `aspect-ratio`: video aspect override
- `av-delay`: audio-video sync offset
- `mirror`: horizontal video flip

## Tasks

Run `task --list` to see all tasks. The main ones:

```bash
task deps         # bundle install (needed again after each Ruby upgrade)
task deps:update  # bump gems within Gemfile constraints, then run the tests
task test         # bundle exec rspec
task lninstall    # install with symlinks (development)
task install      # install copies to XDG directories
task remove       # uninstall
```

## Notes

- Phone-recorded MP4s are a known corruption risk: playtag-python corrupted some of them (Mutagen issue #584). Test fixtures include such files; keep them covered.
