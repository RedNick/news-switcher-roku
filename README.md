# Hourly News Switcher for Roku

The Roku version of the [hourly news switcher](https://github.com/RedNick/news-switcher).
It plays a live news channel full screen and moves to the next channel 60 seconds
before every clock hour, so the new channel's on-the-hour headlines are already
playing. It starts muted.

Roku can't play YouTube, so this version plays each broadcaster's own live
stream (HLS) directly.

## Remote control

| Button          | What it does                     |
| --------------- | -------------------------------- |
| Left / Right    | Previous / next channel          |
| OK (or Play)    | Sound on / off                   |
| Up / Down       | Show / hide the information bar  |
| Back            | Leave the app                    |

If a channel hasn't started playing within 30 seconds, or its stream fails,
the app skips to the next one.

## Channels

The list lives in [`channels.json`](channels.json). Each time the app starts it
downloads the latest copy of that file from this repo's `main` branch, so a
broken stream link can be fixed here without reinstalling the app. A copy is
also built into the app, in case GitHub can't be reached.

Current channels: Al Jazeera English, DW News, France 24 English, NHK World,
CBS News 24/7, ABC News Live, Euronews, TRT World, CNA and Bloomberg.

Stream links change from time to time. If one stops working, search for the
channel's current `.m3u8` link (the [iptv-org](https://github.com/iptv-org/iptv)
lists are a good place to look) and update `channels.json`.

## Building

```sh
tools/build-zip.sh
```

This writes `dist/hourly-news-switcher.zip`.

## Installing on your own Roku (sideloading)

1. On the Roku remote, press **Home ×3, Up ×2, Right, Left, Right, Left, Right**.
2. Follow the on-screen steps to turn on developer mode and choose a password.
   Note the IP address it shows.
3. On a computer on the same network, open `http://<that IP address>` in a
   browser and sign in as `rokudev` with your password.
4. Upload `hourly-news-switcher.zip` and press **Install**.

A Roku can only hold one sideloaded app at a time.

## Publishing as a beta channel

Roku only certifies public store channels whose owner holds the rights to the
video, so this app is shared as a beta channel instead. Beta channels are
installed from an invite link, need no developer mode, and expire after a
while, after which they need re-publishing.

1. Sign up for a free account at [developer.roku.com](https://developer.roku.com).
2. Go to **Dashboard > Beta Apps** (or **Manage Apps > Add App > Beta**) and create one.
3. Upload `hourly-news-switcher.zip` and the artwork in `images/`.
4. Add the email addresses of the Roku accounts that should get it, then open
   the invite link while signed in to that Roku account.
