# Changelog

What changed in each version of Copaste. The newest version is first. Each version's section is also the text for
its GitHub release (tag `vX.Y.Z`).

## 0.4.0 — 2026-10-26

### New

- **Paste several entries at once**: in the clipboard window, ⌘-click to pick entries, ⇧-click or ⇧↑↓ to pick a
  range. ↩ pastes them all in list order; ⌘↩ copies them. Text entries are joined one per line into a single paste;
  with images or files among them, each entry is pasted in turn. esc clears the selection.
- **Notes**: add your own note to any entry with the “Add a note…” field above its preview. Notes are saved as you
  type and included in search; when a search matches a note, the entry shows it under its title with the match
  highlighted. Entries with a note show a note icon.

## 0.3.0 — 2026-10-25

### New

- **Storage used**: Settings › History shows how much space Copaste's history takes on disk (entries, images and
  link previews) and how many entries it holds, with Show in Finder.
- **Delete Entries**: delete history in bulk by when entries were last copied (in the last hour, 24 hours, 7 days or
  month, or more than 7 days, a month, 3 months or a year ago), by type and by group. Pinned entries are kept unless
  you include them. Copaste shows how many entries match and how much space they take, and asks before deleting.

### Changed

- Delete Entries replaces Clear History. Its standard choices (any time, all types, pinned kept) do the same thing.

## 0.2.1 — 2026-10-25

### Fixed

- In dark mode the clipboard window was barely darker than in 0.1.1, so the wallpaper could still show through
  behind the text. Its background is now darker and easier to read on any wallpaper.

## 0.2.0 — 2026-10-25

### New

- **Groups**: put entries in groups and filter the history by group. Create, rename and delete groups in Settings ›
  Groups; add an entry to a group from its right-click menu or Actions (⌘K); pick a group with the folder filter at
  the top of the clipboard window. Entries show their group as a tag. Deleting a group keeps its entries.
- **Move the clipboard window**: drag it by its top or bottom bar. Guides show the centre of the screen and the window
  snaps to it. Copaste remembers where you put it; Settings › Appearance › Center puts it back.
- **⌘1…⌘9 hints**: hold ⌘ in the clipboard window to see which entry each number pastes.
- **Change every shortcut**: Settings › Shortcuts lists all of them. Paste, copy, Actions, open, annotate, save, pin
  and delete can be re-recorded and reset, as well as the shortcut that opens Copaste.
- **Text in Annotate**: the new Text tool places a text box where you click. **Copy to Clipboard** (⌘C) puts the
  edited image on the clipboard without saving it as a new entry.
- **New Settings**: a sidebar with pages and a search field. Type a setting's name to jump to its page.
- **Updates and changelog**: Settings › Updates shows whether a newer Copaste is out, with a Download button, and
  what changed in each version.

### Changed

- New look for the clipboard window: clearer text colours, key caps for each key (⌘ K), a darker background in dark
  mode, and "Search your clipboard" in the search field. The date filter now reads "Any Day".
- Text uses the same sizes as other Mac apps by default and follows macOS's text size. Settings › Appearance ›
  Text size still offers Small, Large and Extra Large.
- "Paste into the app in front" is now "Paste after choosing an entry", with a note on what it does when on or off.

### Fixed

- After choosing an entry, the app you were in didn't always get the keyboard back, so pasting needed a click on its
  window first. Copaste now hands the focus back and waits for that app before pasting.
- Settings and the annotation editor sometimes opened without the keyboard. They now come to the front, ready to type.
- After "Save as New Entry" in Annotate, the clipboard window now opens again with the new entry selected.

## 0.1.1 — 2026-10-25

### New

- **Universal Clipboard**: items copied on your iPhone, iPad or another Mac are saved as soon as they arrive, marked
  "Universal Clipboard". Large items such as photos download in the background. Turn it off in Settings › History ›
  Save Universal Clipboard items immediately.

### Fixed

- Settings (and the annotation and welcome windows) sometimes opened behind other apps, on another Space or on
  another screen. They now come to the front, in the middle of the screen you're on.

## 0.1.0 — 2026-10-25

The first release: a clipboard history for macOS, in the menu bar.

### Clipboard history

- Press **⇧⌘V** in any app to open the floating clipboard window. Change the shortcut in Settings.
- Text, links, e-mail addresses, colours, images and files are recognised, each with its own icon: favicons for
  links, thumbnails for images, swatches for colours.
- Filter by type or by the day an entry was first copied, and search everything, including text in images.
- Entries are grouped under Pinned, Today, Yesterday, This Week, This Month and then by month.
- Details show the source app, type, characters and words, image size, times copied and pasted, and when first and
  last.
- Double-click copies and closes the window, ↩ pastes into the app you were in, ⌘1…⌘9 paste one of the first nine
  entries and ⌘K shows every action for the selected entry.

### Actions

- Open links, write e-mails, copy a colour as HEX, RGB or HSL, save images and text to files, show files in Finder.
- Annotate images with a pen, highlighter, rectangle and arrow; the result is saved as a new entry and copied.

### Your history, your folder

- Choose the folder your history is kept in: a folder in iCloud Drive, Google Drive or OneDrive shares it between
  your Macs.
- Keep history from a day to forever; pinned entries are never cleaned up.
- Passwords marked as secret are never recorded, and whole apps can be ignored.
- Import the images and rich-text copies Raycast keeps.

### Settings

- Text size, copy and paste sounds, toasts after copying and pasting, open at login.
- Send feedback or report a bug from the menu bar or Settings › About.
