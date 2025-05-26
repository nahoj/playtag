Playtag is a simple tool that allows you to play audio and video files that 
have playback options – such as volume adjust, or starting playing the file in 
the middle – set in their tags (in the Playtag tag). You may want to do this if 
you want to apply a change to a media file, so that it takes effect every time 
the file is read, without reencoding the file.

A Playtag tag is a line of text that looks like this:

    v1; t = 0:26; vol = +3dB

This repo provides:
* An mpv script that adds Playtag support to mpv.
* [A player](#player) that
  * acts as a wrapper to VLC adding Playtag support;
  * allows you to [edit](#editing) the Playtag tag on any supported file.

Files with a Playtag tag can still be read with any player that does not support 
Playtag; the tag will then simply be ignored.

The [tag format](#tag-format) is intended to be application-independent.


## Tag format

A Playtag tag is a semicolon-separated list of fields. The first field is 
always `v1`. Other fields are of the form `<parameter> = <value>`. Whitespace 
around `;` and `=` is ignored.

Valid parameters are:

    aspect-ratio = <string>

    av-delay = <float>        (audio-video delay, in seconds)

    mirror = true             (left<>right flip)

    t = <time>-<time>         (start and stop times)
    t = <time>[-]             (start time)
    t = -<time>               (stop time)
        where <time> matches ((\d+:)?\d+:)?\d+(\.\d+)? (e.g. 1:26:03.14)

    vol = <value> <unit>      (volume adjust)
        where <value> is a float
        and <unit> is "dB"/"decibel" or "vg"/"volt gain" or "sg"/"sone gain"
        e.g. -3.2dB  (whitespace between value and unit is optional)


## Player
### Usage

```
Usage: playtag COMMAND [options] [file]

Commands:
  read FILE                   Read playtag from FILE
  write FILE TAG              Write TAG to FILE
  edit FILE                   Edit playtag for FILE interactively
  vlc [VLC_ARGS] FILE         Play FILE with VLC using playtag parameters

Options:
    -d, --debug                      Enable debug output
    -b, --backup                     Create backup files before modifying
    -h, --help                       Show this help message
```

#### Playing with VLC

The `playtag` program can read media files with (or without) a Playtag tag by acting as a 
wrapper to VLC. Do

    Open with > VLC+playtag

from your file manager (you can set it as the default application), or from the 
command line:

    $ playtag vlc <file>+

You may want to alias it in your `.bashrc` or `.zshrc`:

    alias vlc='playtag vlc'

playtag works by reading the tag of the file(s) to open, then calling VLC 
with the appropriate command-line arguments. As a consequence, doing 
`Open...` from inside VLC is not supported: the file will open but the 
tag will be ignored. When called on several files at a time, playtag will start 
one instance of VLC for each file, one after the other.


#### Editing

    $ playtag e[dit] toto.ogg
    v1; t=10; _

You can also use any tag editor that lets you edit arbitrary tags and follow 
the above specification.


### Install

Requirements:

* GNU/Linux (might work on other systems, but not tested)
* Ruby
* TagLib and taglib-ruby
* MKVToolNix and RubyMkvToolNix
* Task and Bundler to install
* mpv or VLC to play the files

To install dependencies on Ubuntu/Debian:

```bash
sudo apt-get install ruby-dev ruby-rubygems build-essential \
  libtag1-dev mkvtoolnix mpv
sudo snap install task
sudo gem install bundler
sudo bundle install
```

Then to install:

```bash
git clone https://github.com/nahoj/playtag.git
cd playtag
task install
```


## Notes
### Alternatives

Some alternatives to Playtag (some of which I didn't know about when I started
writing it):

* [ReplayGain](https://en.wikipedia.org/wiki/ReplayGain) tags, same as Playtag
  for volume adjust only
* [File-specific
  configuration](https://mpv.io/manual/master/#file-specific-configuration-files)
  for MPlayer and mpv, similar to Playtag but stored in separate files
* The aspect ratio of a video is metadata so it can be changed without
  reencoding it, e.g. `ffmpeg -i input.mkv -c copy -aspect 2.35 output.mkv`.

### VLC script

As of 2025, Playtag cannot be implemented as a VLC Lua script. Indeed,

- VLC extensions in the strict sense don't run until they are manually
  activated via the View menu each time VLC is started.
- meta, intf, and service-discovery scripts cannot control playback
  (e.g. seek).
