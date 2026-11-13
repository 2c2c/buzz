# Buzz

Buzz makes a Mac's trackpad buzz like a phone on vibrate. It is meant as a silent alert for coding agents and long-running commands when you can't have sound on: on a plane, in a library, in a coffee shop.

It is a single app that is also a command-line tool. Buzzing needs no permissions and no network access.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/2c2c/buzz/main/install.sh | sh
```

This downloads the latest release, puts `Buzz.app` in `/Applications` (or `~/Applications` if that isn't writable), and sends a test buzz. Because it is downloaded with `curl`, macOS does not show a Gatekeeper warning.

While this repository is private, the command above returns a 404. Use the GitHub CLI instead:

```sh
gh api repos/2c2c/buzz/contents/install.sh -H "Accept: application/vnd.github.raw" | sh
```

You can also download the `.dmg` from the [releases page](https://github.com/2c2c/buzz/releases) and drag the app to Applications. The app is not notarized, so a copy downloaded in a browser is blocked on first launch until you choose **Open Anyway** in System Settings → Privacy & Security.

## Set it up with your agent

Open the app. It shows a prompt to copy and paste into your coding agent. The prompt explains what Buzz can do and asks the agent to add buzzes to its own hooks, next to any alert sounds you already have.

To print the same prompt in a terminal:

```sh
/Applications/Buzz.app/Contents/MacOS/buzz --prompt
```

## Command line

```
buzz                           show the agent setup prompt
buzz --playground              open the playground with every pattern and control
buzz --play PATTERN            buzz now
buzz --play PATTERN --hold N   buzz now; if nothing was touching the trackpad,
                               buzz again on the next touch within N seconds
buzz --prompt                  print the agent setup prompt
buzz --selftest                check the trackpad actuator
buzz --help                    show help
```

The binary is at `/Applications/Buzz.app/Contents/MacOS/buzz`.

### Patterns

A pattern is a list of tokens separated by spaces.

| Token | Meaning |
|---|---|
| `t` | One tap |
| `bN/MS` | A burst of N pulses, MS milliseconds apart. `b40/10` is a 0.4 second buzz |
| `pMS` | Pause for MS milliseconds |
| `@ID` | Optional suffix on `t` or `b` that picks the pulse type: 1–6, 15 or 16. The default is 6 |

Examples:

```sh
buzz --play "b40/10@6"                           # phone buzz
buzz --play "b22/10@6 p140 b22/10@6" --hold 600  # double buzz, repeated on next touch
```

The playground (`--playground`) has presets, a burst builder and a pattern field for finding patterns you like.

### Why `--hold`

The buzz can only be felt with a hand on the trackpad. With `--hold N`, it buzzes immediately, and if nothing was touching the trackpad it waits up to N seconds and buzzes again at the next touch. A newer waiting buzz replaces an older one.

### Shell example

Buzz when a command finishes:

```sh
make test; /Applications/Buzz.app/Contents/MacOS/buzz --play "b40/10@6" --hold 600 &
```

## Requirements

- macOS 13 or later
- A Force Touch trackpad: MacBooks from 2015 on, or a Magic Trackpad with haptics

## Build from source

```sh
swift run -c release buzz --playground   # run directly
Scripts/build-dmg.sh                     # build dist/Buzz.app, the .dmg and the tarball
```

Pushing a tag such as `v0.1.0` runs the release workflow, which builds the app on GitHub and publishes the `.dmg` and tarball as a release.

## How it works

Buzz drives the trackpad's haptic actuator through Apple's private MultitouchSupport framework, and uses the same framework to tell when the trackpad is being touched. Private frameworks can change in any macOS update, and they rule out the Mac App Store.
