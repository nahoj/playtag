| Caution                                                                                                                                                                                                                                      |
|:---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| As of 2022-11-26, adding a tag corrupts some MP4 files (namely, videos I take with my phone and no other that I know of).<br/>See https://github.com/quodlibet/mutagen/issues/584. <br/>Use at your own risk and backup data you care about. |

Playtag is a simple tool that allows you to play audio and video files that 
have playing options – such as volume adjust, or starting playing the file in 
the middle – set in their tags (in the Playtag tag). You may want to do this if 
you want to apply a change to a media file, so that it takes effect every time 
the file is read, without reencoding the file.

A Playtag tag is a line of text that looks like this:

    v1; t = 0:26; vol = +3dB

[The player](#player) acts as a wrapper to MPlayer and VLC to read 
Playtag-tagged files. It also allows you to [edit](#editing) the Playtag tag on 
any supported file.

Files with a Playtag tag can still be read with a player that does not support 
Playtag; the tag will then simply be ignored.

The [tag format](#tag-format) is intended to be application-independent.


## Alternatives

You may be interested in the following alternatives (some of which I didn't 
know about when I started writing Playtag):

* [ReplayGain](https://en.wikipedia.org/wiki/ReplayGain) tags, same as Playtag 
for volume adjust only
* [File-specific 
configuration](https://mpv.io/manual/master/#file-specific-configuration-files) 
for MPlayer and mpv, similar to Playtag but stored in separate files
* The aspect ratio of a video is metadata so it can be changed without 
reencoding it, e.g. `ffmpeg -i input.mkv -c copy -aspect 2.35 output.mkv`.


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
#### Playing

playtag can read media files with (or without) a Playtag tag by acting as a 
wrapper to MPlayer or VLC. Do

    Open with > VLC+playtag

from your file manager (you can set it as the default application), or from the 
command line:

    $ playtag [ m[player] | v[lc] ] <file>+

You may want to alias it in your `.bashrc` or `.zshrc`:

    alias mplayer='playtag mplayer'

playtag works by reading the tag of the file(s) to open, then calling MPlayer 
or VLC with the appropriate command-line arguments. As a consequence, doing 
`Open...` from inside VLC is not supported: the file will open but the 
tag will be ignored. When called on several files at a time, playtag will start 
one instance of MPlayer or VLC for each file, one after the other.


#### Editing

playtag allows you to get and set a given parameter on a file, or to 
raw-edit the whole Playtag tag of a file:

    $ playtag s[et] t=10 toto.ogg

    $ playtag g[et] t toto.ogg
    10

    $ playtag e[dit] toto.ogg
    v1; t=10; _

You can also use any tag editor that lets you edit arbitrary tags and follow 
the above specification.


### Install

Requirements:

* GNU/Linux (untested on other systems; status reports welcome)
* Python 3 with
    * Mutagen (available via `pip3 install mutagen`)
    * (optional) python-magic (`pip3 install python-magic`)
* MKVToolNix 16.x or *older*
* MPlayer or VLC to play the files

To install once do `sudo make install`.

To get playtag with updates you can do:

~~~
git clone https://github.com/nahoj/playtag.git
cd playtag
sudo make lninstall  # creates symlinks
~~~

And then to update:

~~~
cd playtag
git pull
~~~
