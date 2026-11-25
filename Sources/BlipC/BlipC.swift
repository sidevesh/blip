import AppKit
import Blip

// A plain C interface to Blip, for hosts that are not written in Swift (Rust, C, C++).
// Link the static `libBlipC.a` and declare these functions yourself, for example in Rust:
//
//     unsafe extern "C" {
//         fn blip_c_slider(title: *const c_char, level: f64, leading: *const c_char, trailing: *const c_char);
//         fn blip_c_message(title: *const c_char, message: *const c_char, icon: *const c_char) -> i32;
//         fn blip_c_dismiss();
//     }
//
// Every string is UTF-8 and null terminated; icons may be NULL. Icon arguments are
// the names `blip list-icons` prints (e.g. "keyboard-brightness-low"), or any SF Symbol name.
// All functions are safe to call from any thread and return immediately.

private func string(_ pointer: UnsafePointer<CChar>?) -> String? {
  pointer.map { String(cString: $0) }
}

private func icon(_ pointer: UnsafePointer<CChar>?) -> BlipIcon? {
  guard let name = string(pointer), !name.isEmpty else { return nil }
  if let system = BlipSystemIcon(rawValue: name) { return .system(system) }
  return .symbol(name)
}

/// Shows a slider banner: a title, a level from 0 to 1 and an icon at each end.
@_cdecl("blip_c_slider")
public func blip_c_slider(_ title: UnsafePointer<CChar>?, _ level: Double, _ leading: UnsafePointer<CChar>?, _ trailing: UnsafePointer<CChar>?) {
  let content = BlipContent.slider(title: string(title) ?? "", level: level, leading: icon(leading), trailing: icon(trailing))
  Blip.shared.show(content)
}

/// Shows a notice: an icon, a title and a second line. The system's banners always have the second
/// line, so it is required: returns 0 when shown, -1 (and shows nothing) when `message` is NULL or empty.
@_cdecl("blip_c_message")
public func blip_c_message(_ title: UnsafePointer<CChar>?, _ message: UnsafePointer<CChar>?, _ iconName: UnsafePointer<CChar>?) -> Int32 {
  guard let message = string(message), !message.isEmpty else { return -1 }
  Blip.shared.show(.message(title: string(title) ?? "", message: message, icon: icon(iconName)))
  return 0
}

/// Dismisses any banner showing.
@_cdecl("blip_c_dismiss")
public func blip_c_dismiss() {
  Blip.shared.dismiss()
}
