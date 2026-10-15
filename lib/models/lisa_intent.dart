/// LISA v1 — যে কমান্ডগুলো চেনে।
///
/// ⚠️ এখানে যোগ করা প্রতিটা intent-এর জন্য
///    `command_router.dart`-এ একটা case লিখতে হবে,
///    নাহলে কমান্ড বোঝা গেলেও কিছুই হবে না।
enum LisaIntent {
  // ── টর্চ ──
  flashlightOn,
  flashlightOff,

  // ── ভলিউম ──
  volumeUp,
  volumeDown,

  // ── সময় ও তারিখ ──
  tellTime,
  tellDate,

  // ── অ্যালার্ম ──
  setAlarm,

  // ── তথ্য ──
  batteryStatus,

  // ── সাহায্য ("কী কী করতে পারো") ──
  help,

  /// কিছুই মেলেনি — LISA "বুঝতে পারিনি" বলবে।
  /// ⚠️ এটা সবার শেষে রাখো, যোগ করলে শুরুতে নয়।
  unknown,
}
