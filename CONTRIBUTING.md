# Contributing

Adding a theme takes five steps. Everything is scripted; nothing is done by hand.


## 1. Get a `.terminal` file

Porting an iTerm2 color scheme? Convert it:

```sh
$ ./tools/iterm2terminal.swift /path/to/my-theme.itermcolors
```

The converter writes `my-theme.terminal` next to the source file.

Built the theme in Terminal.app instead? Open `Terminal > Settings > Profiles`,
select your profile, then export it from the profile list's `...` menu.

Move the result into `themes/`. Name the file exactly as the theme should read
in the README, for example `Solarized Light.terminal`. Set the same string in
the file's `name` key, which is the profile name Terminal.app shows:

```sh
$ plutil -replace name -string "Solarized Light" "themes/Solarized Light.terminal"
```


## 2. Define every color

Terminal.app reads 21 colors. A theme should set all of them:

- `BackgroundColor`, `TextColor`, `TextBoldColor`, `CursorColor`, `SelectionColor`
- `ANSIBlackColor` through `ANSIWhiteColor` (8)
- `ANSIBrightBlackColor` through `ANSIBrightWhiteColor` (8)

Undefined colors fall back to Terminal.app's own defaults, which rarely suit the
theme. Step 3 lists any key you missed and still renders the preview, so a
partial palette is a warning, not an error. Fix the warnings before opening the
pull request.

Check `SelectionColor` against both `TextColor` and `TextBoldColor`. A selection
color close to either one makes selected text unreadable.


## 3. Generate the preview

```sh
$ ./tools/generate-preview.swift "themes/My Theme.terminal"
```

This writes `screenshots/my_theme.png`. The filename is the theme name
lowercased, with each run of non-alphanumeric characters collapsed to one
underscore.

Do not take screenshots by hand. Previews are rendered from the theme file, so
every image stays identical in size, font, and content.


## 4. Add the README entry

Keep `## Screenshots` alphabetical. Match the surrounding entries:

```markdown
### My Theme ([download](<https://raw.githubusercontent.com/lysyi3m/macos-terminal-themes/master/themes/My Theme.terminal>))

<img src="screenshots/my_theme.png" width="571" alt="Screenshot">
```

The images are rendered at 2x, so `width="571"` displays them at their true size.


## 5. Commit and open a pull request

Use [Conventional Commits][1]: `type(scope): summary`.

```
feat(themes): add Solarized Light
fix(themes): correct Nova selection color
docs: clarify install steps
```

Types used here: `feat`, `fix`, `docs`, `chore`. Keep the subject on one line.

One theme per pull request.

[1]: https://www.conventionalcommits.org


## Tools

### `tools/iterm2terminal.swift`

Converts one or more iTerm2 `.itermcolors` files into `.terminal` profiles.

```sh
$ ./tools/iterm2terminal.swift theme-a.itermcolors theme-b.itermcolors
```

### `tools/generate-preview.swift`

Renders a preview PNG from a `.terminal` file. Reads the colors out of the
profile directly, so no Terminal.app window is involved and the same theme
always produces the same image.

```sh
$ ./tools/generate-preview.swift "themes/My Theme.terminal"   # one theme
$ ./tools/generate-preview.swift themes/*.terminal            # all themes
$ ./tools/generate-preview.swift theme.terminal -o out.png    # custom path
```

Run the bulk form after any change to the preview layout. The tool lists every
theme that leaves colors undefined, so it doubles as a lint pass.

Requires macOS with Menlo installed, which is the default.
