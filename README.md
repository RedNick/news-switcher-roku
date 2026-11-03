# Hourly News Switcher for Roku

The Roku version of the [hourly news switcher](https://github.com/RedNick/news-switcher).
It plays a live news channel full screen and moves to the next channel 20 seconds
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
CBS News 24/7, Euronews, TRT World and Bloomberg.

Stream links change from time to time. If one stops working, search for the
channel's current `.m3u8` link (the [iptv-org](https://github.com/iptv-org/iptv)
lists are a good place to look) and update `channels.json`.

## Building

```sh
tools/build-zip.sh
```

This writes `dist/hourly-news-switcher.zip`.

GitHub Actions also builds it for you. Every pull request gets the zip as a
download on its workflow run, and every change merged to `main` is published as
a release. The newest zip is always at
[releases/latest/download/hourly-news-switcher.zip](https://github.com/RedNick/news-switcher-roku/releases/latest/download/hourly-news-switcher.zip).

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
installed from an invite link and need no developer mode on the TVs that
watch it. They are limited to a small group of testers and expire after a
while, after which they need re-publishing (the dashboard shows the exact
limits).

The Roku dashboard won't take the zip directly. It needs a signed `.pkg` file,
and Roku apps can only be signed on a Roku device, so the first steps happen
on your own Roku.

### One-time setup

1. Sign up for a free developer account at
   [developer.roku.com](https://developer.roku.com/enrollment/standard).
2. Put your Roku in developer mode and sideload the latest zip, as described in
   [Installing on your own Roku](#installing-on-your-own-roku-sideloading).
3. Create a signing key on the Roku. From a computer on the same network, run
   `telnet <Roku IP address> 8080` and type `genkey`.
   - On Windows, turn on the telnet client first by running
     `Enable-WindowsOptionalFeature -Online -FeatureName TelnetClient` in
     PowerShell as administrator.
   - `genkey` prints a **password** and a **DevID**. Save both somewhere safe,
     such as a password manager. Every future update has to be signed with
     this same key. Never commit them to this repo, since it is public.

### Each release

1. Download the latest zip from
   [releases](https://github.com/RedNick/news-switcher-roku/releases/latest/download/hourly-news-switcher.zip)
   and sideload it onto the Roku (open `http://<Roku IP address>`, upload, **Install**).
2. On that same page, open **Packager** (under **Utilities** on newer Roku
   software). Enter an app name, `Hourly News Switcher`, and the `genkey`
   password, then press **Package**. Download the `.pkg` file it makes.
   - If the Roku has been factory reset since you ran `genkey`, the key is
     gone from it. Restore it with **Utilities > Rekey**, using any `.pkg` you
     made before and the same password.
3. In the [developer dashboard](https://developer.roku.com/developer), open
   **Manage apps** (it may be called **Manage channels**), add a new app, and
   choose **Beta** when it asks how to distribute it. For updates, open the
   existing beta app instead.
4. Fill in the name and description, upload the `.pkg`, and use
   `images/icon_focus_fhd.png` (540x405) for the poster artwork.
5. Add the email address of each Roku account that should get the app as a
   tester, then save or publish.
6. Copy the invite link the dashboard gives you. Open it while signed in to
   the Roku account the TV uses, and accept. The app appears on the TV's home
   screen, sometimes only after **Settings > System > System update > Check now**.

Each zip from GitHub Actions already has a higher build number than the last,
so Roku treats it as an update.
