# Buzz

Buzz vibrates a Mac's trackpad like a phone on vibrate. Use it as a silent alert from coding agents and long-running commands when you can't have sound on.

It is one app that also works as a command-line tool. It needs no permissions and no network access.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/2c2c/buzz/main/install.sh | sh
```

This installs `Buzz.app` to `/Applications` from the latest release. A `.dmg` is also available on the [releases page](https://github.com/2c2c/buzz/releases).

Requires macOS 13 or later and a trackpad with haptic feedback.

## Setup

Open Buzz and copy the prompt it shows into your coding agent. The prompt describes the tool and asks the agent to add buzzes to its alert hooks.

To print the prompt instead:

```sh
/Applications/Buzz.app/Contents/MacOS/buzz --prompt
```

## Usage

```
buzz                           show the agent setup prompt
buzz --playground              open the playground to try pulses and patterns
buzz --play PATTERN            buzz now
buzz --play PATTERN --hold N   buzz now, and again on the next touch within N seconds
                               if the trackpad was not being touched
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
| `bN/MS` | A burst of N pulses, MS milliseconds apart |
| `pMS` | A pause of MS milliseconds |
| `@ID` | Optional suffix on `t` or `b` selecting the pulse type: 1–6, 15 or 16 (default 6) |

```sh
buzz --play "b40/10@6"                  # a 0.4 second buzz
buzz --play "b22/10@6 p140 b22/10@6"    # a double buzz
```

## Building

```sh
swift run -c release buzz --playground   # run from source
Scripts/build-dmg.sh                     # build the app, .dmg and tarball into dist/
```

Pushing a `v*` tag builds and publishes a release through GitHub Actions.

## Notes

Buzz uses Apple's private MultitouchSupport framework to drive the trackpad's haptic actuator, so a macOS update may break it.
