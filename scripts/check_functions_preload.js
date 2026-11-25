// Loaded into the Functions emulator through NODE_OPTIONS by scripts/check_run.sh.
// The emulator's firebase-admin stub binds `admin.firestore` (it has no prototype),
// which drops its statics, so `admin.firestore.FieldValue` (used by
// functions/src/bands.js joinBand) is undefined there. Give it a prototype so the
// stub returns it as is, and put the statics back.
const Module = require("module");
const load = Module._load;
Module._load = function (request, parent, isMain) {
  const m = load.apply(this, arguments);
  if (request === "firebase-admin" && m && !m.__checkPatched) {
    try {
      const orig = m.firestore;
      if (typeof orig === "function" && !orig.prototype) {
        const wrapped = function firestore(...args) { return orig.apply(this, args); };
        const statics = load.call(this, "firebase-admin/firestore", parent, false);
        for (const k of ["FieldValue", "Timestamp", "GeoPoint", "FieldPath", "Filter"]) wrapped[k] = statics[k];
        Object.defineProperty(m, "firestore", { value: wrapped, configurable: true });
      }
      Object.defineProperty(m, "__checkPatched", { value: true });
    } catch (e) { console.error("check preload failed", e); }
  }
  return m;
};
