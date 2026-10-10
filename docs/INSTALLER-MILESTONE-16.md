# Milestone 16 — Private inventory report review

**Development only. Read-only. Not a full-client installer.**

## Purpose

Milestone 14 generates a limited local game-file inventory. Milestone 15 tests copying tiny disposable dummy files. Milestone 16 validates the **consistency of a private JSON inventory** before anyone tries to build a large-file process.

The new **Review-Game-File-Report.ps1** tool only reads the JSON and local pinned **config/client-patches.json**. It never opens WoW.exe or game MPQs, downloads archives, copies or modifies client files.

It checks the expected build/patchset, privacy flags, allowlisted relative paths, unique names, byte totals, file hashes or honest Quick-mode absence of hashes, and all five V/Z/J/C/U reference statuses. V and Z are always mandatory for Naxxramas. J and C must not be simultaneously selected.

An internally consistent report is **not proof of game validity, full client completeness, safe redistribution, or current file integrity**. A modified base-file hash may remain internally consistent because we deliberately do not read the actual game files in this step.

## How the owner uses it

1. **Back up** the known-working client first. Create a separate development copy.
2. Extract the latest preview ZIP outside the client.
3. Drag the development client folder containing Wow.exe onto **tools/Inventory-Game-Files.bat** to produce a private game-files JSON.
4. Drag the **game-files-*.json** report onto **tools/Review-Game-File-Report.bat**.
5. Read the summary and warnings. A structurally valid report prints **REPORT STRUCTURE: CONSISTENT**; production installation remains blocked.
6. Review the JSON privately before sharing here. Never commit the JSON to GitHub.

Full inventory hashing can take time on a 17+ GiB game. Quick mode is sizes-only and must always be described as **unverified**.

## Test and safety requirements

- Offline Windows tests use dummy game files and a synthetic patch manifest only.
- Test valid full scans, Quick mode, forged pinned V, duplicate entries, private path rejection, invalid privacy flags and correctly labelled hash mismatches.
- No real-client writes or changes to launcher installation functionality.
- Keep the existing Milestone 15 fixture markers and tiny size limits.
- Do not put personal game reports, MPQs, client archives or artwork in GitHub.

## Next milestone

Review the owner's private scan and assess coverage/unknown MPQ counts; the M14 allowlist does not establish a complete independently verifiable base-game manifest. Investigate crash recovery, disk space, concurrent modification and source authenticity in **synthetic tests** before any real-client copy capability is considered.

**Verified Windows CI:** [run 38054974809](https://github.com/CosmicCuddle/Naxxramas-Client-Setup/actions/runs/38054974809) completed successfully on implementation commit `3ab55d8791dc153b3c761d54c6d70730ae305c60`. The synthetic report review, existing fixture safety tests, launcher smoke tests and preview ZIP upload all passed. This is not a test against a full client.
