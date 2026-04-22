# Imported Spacecraft Status

This folder holds engine-ready spacecraft assets that have already been converted into repo-local formats.

## Currently Imported

- `real/voyager1`
- `trek/bird_of_prey`
- `trek/enterprise_ncc_1701`
- `trek/intrepid_glb`
- `trek/negh_var`
- `trek/voyager_ncc_74656`

## Runtime Notes

- Imported runtime assets are not raw source dumps. Heavier models were normalized and decimated before use so ship switching does not stall the app.
- Runtime materials should resolve within the imported asset folder whenever practical.
- `bird_of_prey` now ships with copied local TGA textures for stable runtime loading.
- Not every imported asset is wired into the live drivable catalog yet; the catalog in `src/spacecraft/spacecraft_catalog.f90` is the runtime gate.

## Still Pending

- Additional Trek ships can still be added later if you want to grow beyond the current set.
- Several imported ships are usable but still candidate replacements once the project is otherwise finished.
