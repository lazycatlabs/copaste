#!/usr/bin/env python3
"""Source of truth for Copaste's UI text. Generates Copaste/App/Resources/Localizable.xcstrings.

Each key maps to (English, Indonesian). English may be a dict {"one": ..., "other": ...} for plurals.
Xcode turns every key into a type-safe symbol, e.g. "appName" -> LocalizedStringResource.appName,
and "imageTitle" (with %lld) -> .imageTitle(_:_:). Run after editing:  python3 scripts/strings.py
"""
import json
from pathlib import Path

S = {
    "appName": ("Copaste", "Copaste"),

    # Actions
    "actionAnnotate": ("Annotate", "Anotasi"),
    "actionCancel": ("Cancel", "Batal"),
    "actionClear": ("Clear", "Bersihkan"),
    "actionComposeEmail": ("Send Email", "Kirim Email"),
    "actionCopy": ("Copy to Clipboard", "Salin ke Clipboard"),
    "actionCopyAs": ("Copy as %@", "Salin sebagai %@"),
    "actionDelete": ("Delete", "Hapus"),
    "actionDone": ("Done", "Selesai"),
    "actionOK": ("OK", "OK"),
    "actionOpen": ("Open", "Buka"),
    "actionOpenInBrowser": ("Open in Browser", "Buka di Browser"),
    "actionPaste": ("Paste", "Tempel"),
    "actionPin": ("Pin", "Sematkan"),
    "actionRemove": ("Remove", "Hapus"),
    "actionReset": ("Reset", "Atur Ulang"),
    "actionRevealInFinder": ("Show in Finder", "Tampilkan di Finder"),
    "actionSaveToFile": ("Save to File…", "Simpan ke File…"),
    "actionUndo": ("Undo", "Urungkan"),
    "actionUnpin": ("Unpin", "Lepas Sematan"),
    "actionsTitle": ("Actions", "Aksi"),

    # Kinds
    "kindText": ("Text", "Teks"),
    "kindLink": ("Link", "Tautan"),
    "kindEmail": ("Email", "Email"),
    "kindColor": ("Color", "Warna"),
    "kindImage": ("Image", "Gambar"),
    "kindFile": ("File", "File"),
    "filterAllTypes": ("All Types", "Semua Tipe"),
    "imageTitle": ("Image (%1$lld×%2$lld)", "Gambar (%1$lld×%2$lld)"),
    "imageFileName": ("Image.png", "Gambar.png"),
    "textFileName": ("Text.txt", "Teks.txt"),
    "annotatedFileName": ("Annotated Image.png", "Gambar Beranotasi.png"),

    # Sections
    "sectionPinned": ("Pinned", "Disematkan"),
    "sectionToday": ("Today", "Hari Ini"),
    "sectionYesterday": ("Yesterday", "Kemarin"),
    "sectionThisWeek": ("This Week", "Minggu Ini"),
    "sectionThisMonth": ("This Month", "Bulan Ini"),

    # Clipboard window and list
    "searchPlaceholder": ("Type to filter entries…", "Ketik untuk menyaring…"),
    "emptyTitle": ("Nothing here yet", "Belum ada apa-apa"),
    "emptyMessage": ("Copy something and it shows up here.", "Salin sesuatu dan akan muncul di sini."),
    "statusPaused": ("Recording paused", "Perekaman dijeda"),
    "previewUnavailable": ("Preview unavailable", "Pratinjau tidak tersedia"),
    "errorTitle": ("Something went wrong", "Terjadi kesalahan"),
    "toastCopied": ("“%@” copied — ready to paste", "“%@” disalin — siap ditempel"),
    "toastAnnotated": ("Annotated image saved and copied", "Gambar beranotasi disimpan dan disalin"),

    # Information
    "infoTitle": ("Information", "Informasi"),
    "infoSource": ("Source", "Sumber"),
    "infoType": ("Type", "Tipe"),
    "infoCharacters": ("Characters", "Karakter"),
    "infoWords": ("Words", "Kata"),
    "infoURL": ("URL", "URL"),
    "infoTitleLabel": ("Title", "Judul"),
    "infoAddress": ("Address", "Alamat"),
    "infoDimensions": ("Dimensions", "Dimensi"),
    "infoRecognizedText": ("Text in image", "Teks di gambar"),
    "infoFiles": ("Files", "File"),
    "infoSize": ("Size", "Ukuran"),
    "infoTimesCopied": ("Times copied", "Berapa kali disalin"),
    "infoTimesPasted": ("Times pasted", "Berapa kali ditempel"),
    "infoFirstCopied": ("First copied", "Pertama disalin"),
    "infoLastCopied": ("Last copied", "Terakhir disalin"),
    "infoFirstPasted": ("First pasted", "Pertama ditempel"),
    "infoLastPasted": ("Last pasted", "Terakhir ditempel"),
    "infoDevice": ("Device", "Perangkat"),

    # Annotate
    "annotateTool": ("Tool", "Alat"),
    "annotateWidth": ("Line width", "Tebal garis"),
    "annotateDone": ("Save as New Entry", "Simpan sebagai Entri Baru"),
    "toolPen": ("Pen", "Pena"),
    "toolHighlighter": ("Highlighter", "Stabilo"),
    "toolRectangle": ("Rectangle", "Kotak"),
    "toolArrow": ("Arrow", "Panah"),

    # Menu bar
    "menuOpenHistory": ("Open Clipboard History  %@", "Buka Riwayat Clipboard  %@"),
    "menuPause": ("Pause Recording", "Jeda Perekaman"),
    "menuSettings": ("Settings…", "Pengaturan…"),
    "menuQuit": ("Quit Copaste", "Keluar dari Copaste"),

    # Vault
    "vaultIntro": (
        "Choose a folder for your clipboard history. Pick one inside iCloud Drive, Google Drive or OneDrive to share it between your devices.",
        "Pilih folder untuk riwayat clipboard. Pilih folder di iCloud Drive, Google Drive atau OneDrive agar bisa dipakai bersama di semua perangkat.",
    ),
    "vaultChoose": ("Choose Folder…", "Pilih Folder…"),
    "vaultChange": ("Change Folder…", "Ganti Folder…"),
    "vaultReveal": ("Show in Finder", "Tampilkan di Finder"),
    "vaultUseFolder": ("Use This Folder", "Pakai Folder Ini"),
    "vaultHint": (
        "Each entry is one small JSON file, so cloud sync stays fast and conflicts stay small.",
        "Setiap entri disimpan sebagai satu file JSON kecil, jadi sinkronisasi cloud tetap cepat dan konflik tetap kecil.",
    ),

    # Settings
    "settingsTitle": ("Settings", "Pengaturan"),
    "settingsVault": ("Vault", "Vault"),
    "settingsVaultFolder": ("Folder", "Folder"),
    "settingsHistory": ("History", "Riwayat"),
    "settingsKeepHistory": ("Keep history for", "Simpan riwayat selama"),
    "settingsLinkPreviews": ("Fetch link titles, icons and previews", "Ambil judul, ikon dan pratinjau tautan"),
    "settingsTextRecognition": ("Text Recognition", "Pengenalan Teks"),
    "settingsRecognitionMode": ("Recognition Mode", "Mode Pengenalan"),
    "settingsTextRecognitionFooter": (
        "Text in images is found on this device so it can be searched. Accurate mode uses more CPU.",
        "Teks di gambar dikenali di perangkat ini agar bisa dicari. Mode akurat memakai lebih banyak CPU.",
    ),
    "recognitionFast": ("Fast", "Cepat"),
    "recognitionAccurate": ("Accurate", "Akurat"),
    "settingsPasting": ("Pasting", "Menempel"),
    "settingsPasteDirectly": ("Paste into the app in front", "Tempel langsung ke aplikasi yang aktif"),
    "settingsAccessibilityNeeded": ("Needs Accessibility access to send ⌘V.", "Perlu akses Aksesibilitas untuk mengirim ⌘V."),
    "settingsGrantAccess": ("Grant Access…", "Beri Akses…"),
    "settingsShortcut": ("Open clipboard history", "Buka riwayat clipboard"),
    "settingsLaunchAtLogin": ("Open at login", "Buka saat login"),
    "settingsIgnoredApps": ("Ignored Apps", "Aplikasi yang Diabaikan"),
    "settingsIgnoredAppsFooter": (
        "Copies from these apps are never recorded. Passwords marked as secret by any app are always skipped.",
        "Salinan dari aplikasi ini tidak pernah direkam. Kata sandi yang ditandai rahasia oleh aplikasi apa pun selalu dilewati.",
    ),
    "settingsAddApp": ("Add App…", "Tambah Aplikasi…"),
    "settingsClearHistory": ("Clear History", "Hapus Riwayat"),
    "settingsClearConfirm": ("Delete every entry that isn't pinned?", "Hapus semua entri yang tidak disematkan?"),
    "settingsClearFooter": ("Pinned entries are kept.", "Entri yang disematkan tetap disimpan."),
    "settingsSounds": ("Sounds", "Suara"),
    "settingsCopySound": ("When copying", "Saat menyalin"),
    "settingsPasteSound": ("When pasting", "Saat menempel"),
    "soundNone": ("None", "Tidak ada"),
    "shortcutPressKeys": ("Press keys…", "Tekan tombol…"),
    "settingsAbout": ("About", "Tentang"),
    "aboutVersion": ("Version", "Versi"),
    "supportFeedback": ("Send Feedback", "Kirim Masukan"),
    "supportBugReport": ("Report a Bug", "Laporkan Bug"),
    "supportWebsite": ("Website", "Situs Web"),
    "feedbackSubject": ("Copaste Feedback", "Masukan untuk Copaste"),
    "bugReportSubject": ("Copaste Bug Report", "Laporan Bug Copaste"),
    "bugReportBody": (
        "What happened?\n\n\nWhat did you expect?\n\n\nSteps to reproduce:\n1. \n\n—\nCopaste %1$@\n%2$@",
        "Apa yang terjadi?\n\n\nApa yang Anda harapkan?\n\n\nLangkah untuk mengulanginya:\n1. \n\n—\nCopaste %1$@\n%2$@",
    ),
    "retentionDay": ("1 Day", "1 Hari"),
    "retentionWeek": ("1 Week", "1 Minggu"),
    "retentionMonth": ("1 Month", "1 Bulan"),
    "retentionThreeMonths": ("3 Months", "3 Bulan"),
    "retentionYear": ("1 Year", "1 Tahun"),
    "retentionForever": ("Forever", "Selamanya"),
}

LANGS = ("en", "id")


def unit(value):
    return {"stringUnit": {"state": "translated", "value": value}}


def localization(value):
    if isinstance(value, dict):
        return {"variations": {"plural": {form: unit(text) for form, text in value.items()}}}
    return unit(value)


catalog = {
    "sourceLanguage": "en",
    "strings": {
        key: {
            "extractionState": "manual",
            "localizations": {lang: localization(text) for lang, text in zip(LANGS, values)},
        }
        for key, values in sorted(S.items())
    },
    "version": "1.0",
}

out = Path(__file__).resolve().parent.parent / "Copaste" / "App" / "Resources" / "Localizable.xcstrings"
out.write_text(json.dumps(catalog, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
print(f"wrote {len(S)} strings to {out}")
