# Imported Spacecraft Status

This folder holds engine-ready spacecraft assets that have already been converted into repo-local formats.

## Currently Imported

- `real/voyager1`
- `real/iss`
- `real/space_shuttle`
- `trek/enterprise_d`
- `trek/enterprise_ncc_1701_tmp`
- `trek/bird_of_prey`
- `trek/borg_cube`

## Runtime Notes

- Imported runtime assets are not raw source dumps. Heavier models were normalized and decimated before use so ship switching does not stall the app.
- Runtime materials should resolve within the imported asset folder whenever practical.
- `bird_of_prey` now ships with copied local TGA textures for stable runtime loading.
- `borg_cube` currently uses material-color fallback because the local source bundle did not include the external texture files referenced by the original material.
- `space_shuttle` is currently functional but visually weaker than the better imported ships.

## Still Pending

- Additional Trek ships can still be added later if you want to grow beyond the current set.
- Several imported ships are usable but still candidate replacements once the project is otherwise finished.
