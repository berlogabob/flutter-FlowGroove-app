# Audit crawl scripts
Run these scripts from the repository root.
`cap.py` captures screenshots and accessibility hierarchies using adb.
`crawl.py` explores screens by their accessibility labels.
`flows.py` runs the named audit flows, or all flows when no names are given.
Set `AUDIT_RUN` to the audit run directory used for output.
If `AUDIT_RUN` is unset, `cap.py` reads the existing rundir file.
The run directory must contain `screens` and `hierarchy` directories.
