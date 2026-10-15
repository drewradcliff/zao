# Keys

zao recognizes the different codes Ghostty, iTerm2, Terminal, and tmux send for the same key. `Cmd` keys only reach the shell if the terminal sends them: Ghostty does by default, and in iTerm2 choose the Natural Text Editing preset under Settings → Profiles → Keys. The `Ctrl` equivalents work everywhere.

## Editing

| Key | Action |
| --- | --- |
| `Option-←` `Option-→` | Move by word (`Ctrl` works too) |
| `Cmd-←` `Cmd-→` / `Home` `End` | Start or end of line (`Ctrl-A` `Ctrl-E` work too) |
| `Option-Backspace` | Delete word before cursor (`Ctrl-Backspace`, `Ctrl-W` work too) |
| `Option-Delete` | Delete word after cursor |
| `Cmd-Backspace` / `Ctrl-U` | Delete to start of line |
| `Ctrl-K` | Delete to end of line |
| `Ctrl-X Ctrl-E` | Edit the command in `$EDITOR` |
| `Ctrl-L` | Clear the screen |

Word movement stops at punctuation, as in a macOS text field: `Option-Backspace` on `~/repos/zao` deletes `zao`.

## Suggestions

As you type, the rest of a matching command from your history shows in gray.

| Key | Action |
| --- | --- |
| `→` / `End` | Accept the suggestion |
| `Option-→` | Accept the next word of it |
| `Esc` | Dismiss it |

## Completion

| Key | Action |
| --- | --- |
| `Tab` | Open the menu, or complete if there's only one match |
| `←` `↑` `↓` `→` | Move through matches |
| `Tab` `Shift-Tab` | Next or previous match |
| `Enter` | Pick the match, without running the command |
| `Esc` | Close the menu and put back what you typed |

Matching ignores case, and `fb` matches `foo-bar`.

## History

| Key | Action |
| --- | --- |
| `↑` `↓` | Step through commands that start with what you've typed |
| `Ctrl-R` | Search all history. `Enter` puts the command on the line to edit or run |

Every open shell shares one history, so a command you ran in one tab is in `Ctrl-R` in another.

## Pickers

On an empty line, a picker goes where you choose. Partway through a command, it inserts the choice at the cursor.

| Key | Picks | On an empty line |
| --- | --- | --- |
| `Ctrl-G` | A branch, most recent first | `git switch` to it |
| `Ctrl-O` | A directory you've visited, most used first | `cd` to it |
| `Ctrl-T` | A file in this directory | Inserts its path |

In a picker, type to filter, `↑` `↓` to move, `Enter` to choose, `Esc` to cancel.
