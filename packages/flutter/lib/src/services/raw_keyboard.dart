// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'binding.dart';
import 'hardware_keyboard.dart';
import 'keyboard_key.dart';
import 'raw_keyboard_android.dart';
import 'raw_keyboard_fuchsia.dart';
import 'raw_keyboard_ios.dart';
import 'raw_keyboard_linux.dart';
import 'raw_keyboard_macos.dart';
import 'raw_keyboard_web.dart';
import 'raw_keyboard_windows.dart';
import 'system_channels.dart';

/// An enum describing the side of the keyboard that a key is on, to allow
/// discrimination between which key is pressed (e.g. the left or right SHIFT
/// key).
///
/// See also:
///
///  * [RawKeyEventData.isModifierPressed], which accepts this enum as an
///    argument.
enum KeyboardSide {
  /// Matches if either the left, right or both versions of the key are pressed.
  any,

  /// Matches the left version of the key.
  left,

  /// Matches the right version of the key.
  right,

  /// Matches the left and right version of the key pressed simultaneously.
  all,
}

/// An enum describing the type of modifier key that is being pressed.
///
/// See also:
///
///  * [RawKeyEventData.isModifierPressed], which accepts this enum as an
///    argument.
enum ModifierKey {
  /// The CTRL modifier key.
  ///
  /// Typically, there are two of these.
  controlModifier,

  /// The SHIFT modifier key.
  ///
  /// Typically, there are two of these.
  shiftModifier,

  /// The ALT modifier key.
  ///
  /// Typically, there are two of these.
  altModifier,

  /// The META modifier key.
  ///
  /// Typically, there are two of these. This is, for example, the Windows key
  /// on Windows (⊞), the Command (⌘) key on macOS and iOS, and the Search (🔍)
  /// key on Android.
  metaModifier,

  /// The CAPS LOCK modifier key.
  ///
  /// Typically, there is one of these. Only shown as "pressed" when the caps
  /// lock is on, so on a key up when the mode is turned on, on each key press
  /// when it's enabled, and on a key down when it is turned off.
  capsLockModifier,

  /// The NUM LOCK modifier key.
  ///
  /// Typically, there is one of these. Only shown as "pressed" when the num
  /// lock is on, so on a key up when the mode is turned on, on each key press
  /// when it's enabled, and on a key down when it is turned off.
  numLockModifier,

  /// The SCROLL LOCK modifier key.
  ///
  /// Typically, there is one of these.  Only shown as "pressed" when the scroll
  /// lock is on, so on a key up when the mode is turned on, on each key press
  /// when it's enabled, and on a key down when it is turned off.
  scrollLockModifier,

  /// The FUNCTION (Fn) modifier key.
  ///
  /// Typically, there is one of these.
  functionModifier,

  /// The SYMBOL modifier key.
  ///
  /// Typically, there is one of these.
  symbolModifier,
}

/// Base class for platform-specific key event data.
///
/// This base class exists to have a common type to use for each of the
/// target platform's key event data structures.
///
/// See also:
///
///  * [RawKeyEventDataAndroid], a specialization for Android.
///  * [RawKeyEventDataFuchsia], a specialization for Fuchsia.
///  * [RawKeyDownEvent] and [RawKeyUpEvent], the classes that hold the
///    reference to [RawKeyEventData] subclasses.
///  * [RawKeyboard], which uses these interfaces to expose key data.
@immutable
abstract class RawKeyEventData with Diagnosticable {
  /// Abstract const constructor. This constructor enables subclasses to provide
  /// const constructors so that they can be used in const expressions.
  const RawKeyEventData();

  /// Returns true if the given [ModifierKey] was pressed at the time of this
  /// event.
  ///
  /// If [side] is specified, then this restricts its check to the specified
  /// side of the keyboard. Defaults to checking for the key being down on
  /// either side of the keyboard. If there is only one instance of the key on
  /// the keyboard, then [side] is ignored.
  bool isModifierPressed(ModifierKey key, { KeyboardSide side = KeyboardSide.any });

  /// Returns a [KeyboardSide] enum value that describes which side or sides of
  /// the given keyboard modifier key were pressed at the time of this event.
  ///
  /// If the modifier key wasn't pressed at the time of this event, returns
  /// null. If the given key only appears in one place on the keyboard, returns
  /// [KeyboardSide.all] if pressed. If the given platform does not specify
  /// the side, return [KeyboardSide.any].
  KeyboardSide? getModifierSide(ModifierKey key);

  /// Returns true if a CTRL modifier key was pressed at the time of this event,
  /// regardless of which side of the keyboard it is on.
  ///
  /// Use [isModifierPressed] if you need to know which control key was pressed.
  bool get isControlPressed => isModifierPressed(ModifierKey.controlModifier, side: KeyboardSide.any);

  /// Returns true if a SHIFT modifier key was pressed at the time of this
  /// event, regardless of which side of the keyboard it is on.
  ///
  /// Use [isModifierPressed] if you need to know which shift key was pressed.
  bool get isShiftPressed => isModifierPressed(ModifierKey.shiftModifier, side: KeyboardSide.any);

  /// Returns true if a ALT modifier key was pressed at the time of this event,
  /// regardless of which side of the keyboard it is on.
  ///
  /// Use [isModifierPressed] if you need to know which alt key was pressed.
  bool get isAltPressed => isModifierPressed(ModifierKey.altModifier, side: KeyboardSide.any);

  /// Returns true if a META modifier key was pressed at the time of this event,
  /// regardless of which side of the keyboard it is on.
  ///
  /// Use [isModifierPressed] if you need to know which meta key was pressed.
  bool get isMetaPressed => isModifierPressed(ModifierKey.metaModifier, side: KeyboardSide.any);

  /// Returns a map of modifier keys that were pressed at the time of this
  /// event, and the keyboard side or sides that the key was on.
  Map<ModifierKey, KeyboardSide> get modifiersPressed {
    final Map<ModifierKey, KeyboardSide> result = <ModifierKey, KeyboardSide>{};
    for (final ModifierKey key in ModifierKey.values) {
      if (isModifierPressed(key)) {
        final KeyboardSide? side = getModifierSide(key);
        if (side != null) {
          result[key] = side;
        }
        assert(() {
          if (side == null) {
            debugPrint(
              'Raw key data is returning inconsistent information for '
              'pressed modifiers. isModifierPressed returns true for $key '
              'being pressed, but when getModifierSide is called, it says '
              'that no modifiers are pressed.',
            );
            if (this is RawKeyEventDataAndroid) {
              debugPrint('Android raw key metaState: ${(this as RawKeyEventDataAndroid).metaState}');
            }
          }
          return true;
        }());
      }
    }
    return result;
  }

  /// Returns an object representing the physical location of this key on a
  /// QWERTY keyboard.
  ///
  /// {@macro flutter.services.RawKeyEvent.physicalKey}
  ///
  /// See also:
  ///
  ///  * [logicalKey] for the non-location-specific key generated by this event.
  ///  * [RawKeyEvent.physicalKey], where this value is available on the event.
  PhysicalKeyboardKey get physicalKey;

  /// Returns an object representing the logical key that was pressed.
  ///
  /// {@macro flutter.services.RawKeyEvent.logicalKey}
  ///
  /// See also:
  ///
  ///  * [physicalKey] for the location-specific key generated by this event.
  ///  * [RawKeyEvent.logicalKey], where this value is available on the event.
  LogicalKeyboardKey get logicalKey;

  /// Returns the Unicode string representing the label on this key.
  ///
  /// This value is an empty string if there's no key label data for a key.
  ///
  /// {@template flutter.services.RawKeyEventData.keyLabel}
  /// Do not use the [keyLabel] to compose a text string: it will be missing
  /// special processing for Unicode strings for combining characters and other
  /// special characters, and the effects of modifiers.
  ///
  /// If you are looking for the character produced by a key event, use
  /// [RawKeyEvent.character] instead.
  ///
  /// If you are composing text strings, use the [TextField] or
  /// [CupertinoTextField] widgets, since those automatically handle many of the
  /// complexities of managing keyboard input, like showing a soft keyboard or
  /// interacting with an input method editor (IME).
  /// {@endtemplate}
  String get keyLabel;

  /// Whether a key down event, and likewise its accompanying key up event,
  /// should be dispatched.
  ///
  /// Certain events on some platforms should not be dispatched to listeners
  /// according to Flutter's event model. For example, on macOS, Fn keys are
  /// skipped to be consistent with other platform. On Win32, events dispatched
  /// for IME (`VK_PROCESSKEY`) are also skipped.
  ///
  /// This method will be called upon every down events. By default, this method
  /// always return true. Subclasses should override this method to define the
  /// filtering rule for the platform. If this method returns false for an event
  /// message, the event will not be dispatched to listeners, but respond with
  /// "handled: true" immediately. Moreover, the following up event with the
  /// same physical key will also be skipped.
  bool shouldDispatchEvent() {
    return true;
  }
}

/// Defines the interface for raw key events.
///
/// Raw key events pass through as much information as possible from the
/// underlying platform's key events, which allows them to provide a high level
/// of fidelity but a low level of portability.
///
/// The event also provides an abstraction for the [physicalKey] and the
/// [logicalKey], describing the physical location of the key, and the logical
/// meaning of the key, respectively. These are more portable representations of
/// the key events, and should produce the same results regardless of platform.
///
/// See also:
///
///  * [LogicalKeyboardKey], an object that describes the logical meaning of a
///    key.
///  * [PhysicalKeyboardKey], an object that describes the physical location of
///    a key.
///  * [RawKeyDownEvent], a specialization for events representing the user
///    pressing a key.
///  * [RawKeyUpEvent], a specialization for events representing the user
///    releasing a key.
///  * [RawKeyboard], which uses this interface to expose key data.
///  * [RawKeyboardListener], a widget that listens for raw key events.
@immutable
abstract class RawKeyEvent with Diagnosticable {
  /// Abstract const constructor. This constructor enables subclasses to provide
  /// const constructors so that they can be used in const expressions.
  const RawKeyEvent({
    required this.data,
    this.character,
  });

  /// Creates a concrete [RawKeyEvent] class from a message in the form received
  /// on the [SystemChannels.keyEvent] channel.
  factory RawKeyEvent.fromMessage(Map<String, dynamic> message) {
    String? character;
    RawKeyEventData _dataFromWeb() {
      final String? key = message['key'] as String?;
      if (key != null && key.isNotEmpty && key.length == 1) {
        character = key;
      }
      return RawKeyEventDataWeb(
        code: message['code'] as String? ?? '',
        key: key ?? '',
        location: message['location'] as int? ?? 0,
        metaState: message['metaState'] as int? ?? 0,
      );
    }

    final RawKeyEventData data;
    if (kIsWeb) {
      data = _dataFromWeb();
    } else {
      final String keymap = message['keymap'] as String;
      switch (keymap) {
        case 'android':
          data = RawKeyEventDataAndroid(
            flags: message['flags'] as int? ?? 0,
            codePoint: message['codePoint'] as int? ?? 0,
            keyCode: message['keyCode'] as int? ?? 0,
            plainCodePoint: message['plainCodePoint'] as int? ?? 0,
            scanCode: message['scanCode'] as int? ?? 0,
            metaState: message['metaState'] as int? ?? 0,
            eventSource: message['source'] as int? ?? 0,
            vendorId: message['vendorId'] as int? ?? 0,
            productId: message['productId'] as int? ?? 0,
            deviceId: message['deviceId'] as int? ?? 0,
            repeatCount: message['repeatCount'] as int? ?? 0,
          );
          if (message.containsKey('character')) {
            character = message['character'] as String?;
          }
          break;
        case 'fuchsia':
          final int codePoint = message['codePoint'] as int? ?? 0;
          data = RawKeyEventDataFuchsia(
            hidUsage: message['hidUsage'] as int? ?? 0,
            codePoint: codePoint,
            modifiers: message['modifiers'] as int? ?? 0,
          );
          if (codePoint != 0) {
            character = String.fromCharCode(codePoint);
          }
          break;
        case 'macos':
          data = RawKeyEventDataMacOs(
            characters: message['characters'] as String? ?? '',
            charactersIgnoringModifiers: message['charactersIgnoringModifiers'] as String? ?? '',
            keyCode: message['keyCode'] as int? ?? 0,
            modifiers: message['modifiers'] as int? ?? 0,
          );
          character = message['characters'] as String?;
          break;
        case 'ios':
          data = RawKeyEventDataIos(
            characters: message['characters'] as String? ?? '',
            charactersIgnoringModifiers: message['charactersIgnoringModifiers'] as String? ?? '',
            keyCode: message['keyCode'] as int? ?? 0,
            modifiers: message['modifiers'] as int? ?? 0,
          );
          break;
        case 'linux':
          final int unicodeScalarValues = message['unicodeScalarValues'] as int? ?? 0;
          data = RawKeyEventDataLinux(
            keyHelper: KeyHelper(message['toolkit'] as String? ?? ''),
            unicodeScalarValues: unicodeScalarValues,
            keyCode: message['keyCode'] as int? ?? 0,
            scanCode: message['scanCode'] as int? ?? 0,
            modifiers: message['modifiers'] as int? ?? 0,
            isDown: message['type'] == 'keydown',
          );
          if (unicodeScalarValues != 0) {
            character = String.fromCharCode(unicodeScalarValues);
          }
          break;
        case 'windows':
          final int characterCodePoint = message['characterCodePoint'] as int? ?? 0;
          data = RawKeyEventDataWindows(
            keyCode: message['keyCode'] as int? ?? 0,
            scanCode: message['scanCode'] as int? ?? 0,
            characterCodePoint: characterCodePoint,
            modifiers: message['modifiers'] as int? ?? 0,
          );
          if (characterCodePoint != 0) {
            character = String.fromCharCode(characterCodePoint);
          }
          break;
        case 'web':
          data = _dataFromWeb();
          break;
        default:
          /// This exception would only be hit on platforms that haven't yet
          /// implemented raw key events, but will only be triggered if the
          /// engine for those platforms sends raw key event messages in the
          /// first place.
          throw FlutterError('Unknown keymap for key events: $keymap');
      }
    }
    final String type = message['type'] as String;
    switch (type) {
      case 'keydown':
        return RawKeyDownEvent(data: data, character: character);
      case 'keyup':
        return RawKeyUpEvent(data: data);
      default:
        throw FlutterError('Unknown key event type: $type');
    }
  }

  /// Returns true if the given [KeyboardKey] is pressed.
  bool isKeyPressed(LogicalKeyboardKey key) => RawKeyboard.instance.keysPressed.contains(key);

  /// Returns true if a CTRL modifier key is pressed, regardless of which side
  /// of the keyboard it is on.
  ///
  /// Use [isKeyPressed] if you need to know which control key was pressed.
  bool get isControlPressed {
    return isKeyPressed(LogicalKeyboardKey.controlLeft) || isKeyPressed(LogicalKeyboardKey.controlRight);
  }

  /// Returns true if a SHIFT modifier key is pressed, regardless of which side
  /// of the keyboard it is on.
  ///
  /// Use [isKeyPressed] if you need to know which shift key was pressed.
  bool get isShiftPressed {
    return isKeyPressed(LogicalKeyboardKey.shiftLeft) || isKeyPressed(LogicalKeyboardKey.shiftRight);
  }

  /// Returns true if a ALT modifier key is pressed, regardless of which side
  /// of the keyboard it is on.
  ///
  /// Note that the ALTGR key that appears on some keyboards is considered to be
  /// the same as [LogicalKeyboardKey.altRight] on some platforms (notably
  /// Android). On platforms that can distinguish between `altRight` and
  /// `altGr`, a press of `altGr` will not return true here, and will need to be
  /// tested for separately.
  ///
  /// Use [isKeyPressed] if you need to know which alt key was pressed.
  bool get isAltPressed {
    return isKeyPressed(LogicalKeyboardKey.altLeft) || isKeyPressed(LogicalKeyboardKey.altRight);
  }

  /// Returns true if a META modifier key is pressed, regardless of which side
  /// of the keyboard it is on.
  ///
  /// Use [isKeyPressed] if you need to know which meta key was pressed.
  bool get isMetaPressed {
    return isKeyPressed(LogicalKeyboardKey.metaLeft) || isKeyPressed(LogicalKeyboardKey.metaRight);
  }

  /// Returns an object representing the physical location of this key.
  ///
  /// {@template flutter.services.RawKeyEvent.physicalKey}
  /// The [PhysicalKeyboardKey] ignores the key map, modifier keys (like SHIFT),
  /// and the label on the key. It describes the location of the key as if it
  /// were on a QWERTY keyboard regardless of the keyboard mapping in effect.
  ///
  /// [PhysicalKeyboardKey]s are used to describe and test for keys in a
  /// particular location.
  ///
  /// For instance, if you wanted to make a game where the key to the right of
  /// the CAPS LOCK key made the player move left, you would be comparing the
  /// result of this `physicalKey` with [PhysicalKeyboardKey.keyA], since that
  /// is the key next to the CAPS LOCK key on a QWERTY keyboard. This would
  /// return the same thing even on a French keyboard where the key next to the
  /// CAPS LOCK produces a "Q" when pressed.
  ///
  /// If you want to make your app respond to a key with a particular character
  /// on it regardless of location of the key, use [RawKeyEvent.logicalKey] instead.
  /// {@endtemplate}
  ///
  /// See also:
  ///
  ///  * [logicalKey] for the non-location specific key generated by this event.
  ///  * [character] for the character generated by this keypress (if any).
  PhysicalKeyboardKey get physicalKey => data.physicalKey;

  /// Returns an object representing the logical key that was pressed.
  ///
  /// {@template flutter.services.RawKeyEvent.logicalKey}
  /// This method takes into account the key map and modifier keys (like SHIFT)
  /// to determine which logical key to return.
  ///
  /// If you are looking for the character produced by a key event, use
  /// [RawKeyEvent.character] instead.
  ///
  /// If you are collecting text strings, use the [TextField] or
  /// [CupertinoTextField] widgets, since those automatically handle many of the
  /// complexities of managing keyboard input, like showing a soft keyboard or
  /// interacting with an input method editor (IME).
  /// {@endtemplate}
  LogicalKeyboardKey get logicalKey => data.logicalKey;

  /// Returns the Unicode character (grapheme cluster) completed by this
  /// keystroke, if any.
  ///
  /// This will only return a character if this keystroke, combined with any
  /// preceding keystroke(s), generated a character, and only on a "key down"
  /// event. It will return null if no character has been generated by the
  /// keystroke (e.g. a "dead" or "combining" key), or if the corresponding key
  /// is a key without a visual representation, such as a modifier key or a
  /// control key.
  ///
  /// This can return multiple Unicode code points, since some characters (more
  /// accurately referred to as grapheme clusters) are made up of more than one
  /// code point.
  ///
  /// The `character` doesn't take into account edits by an input method editor
  /// (IME), or manage the visibility of the soft keyboard on touch devices. For
  /// composing text, use the [TextField] or [CupertinoTextField] widgets, since
  /// those automatically handle many of the complexities of managing keyboard
  /// input.
  final String? character;

  /// Platform-specific information about the key event.
  final RawKeyEventData data;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<LogicalKeyboardKey>('logicalKey', logicalKey));
    properties.add(DiagnosticsProperty<PhysicalKeyboardKey>('physicalKey', physicalKey));
  }
}

/// The user has pressed a key on the keyboard.
///
/// See also:
///
///  * [RawKeyboard], which uses this interface to expose key data.
class RawKeyDownEvent extends RawKeyEvent {
  /// Creates a key event that represents the user pressing a key.
  const RawKeyDownEvent({
    required RawKeyEventData data,
    String? character,
  }) : super(data: data, character: character);
}

/// The user has released a key on the keyboard.
///
/// See also:
///
///  * [RawKeyboard], which uses this interface to expose key data.
class RawKeyUpEvent extends RawKeyEvent {
  /// Creates a key event that represents the user releasing a key.
  const RawKeyUpEvent({
    required RawKeyEventData data,
    String? character,
  }) : super(data: data, character: character);
}

/// A callback type used by [RawKeyboard.keyEventHandler] to send key events to
/// a handler that can determine if the key has been handled or not.
///
/// The handler should return true if the key has been handled, and false if the
/// key was not handled.  It must not return null.
typedef RawKeyEventHandler = bool Function(RawKeyEvent event);

/// An interface for listening to raw key events.
///
/// Raw key events pass through as much information as possible from the
/// underlying platform's key events, which makes them provide a high level of
/// fidelity but a low level of portability.
///
/// A [RawKeyboard] is useful for listening to raw key events and hardware
/// buttons that are represented as keys. Typically used by games and other apps
/// that use keyboards for purposes other than text entry.
///
/// These key events are typically only key events generated by a hardware
/// keyboard, and not those from software keyboards or input method editors.
///
/// See also:
///
///  * [RawKeyDownEvent] and [RawKeyUpEvent], the classes used to describe
///    specific raw key events.
///  * [RawKeyboardListener], a widget that listens for raw key events.
///  * [SystemChannels.keyEvent], the low-level channel used for receiving
///    events from the system.
class RawKeyboard {
  RawKeyboard._();

  /// The shared instance of [RawKeyboard].
  static final RawKeyboard instance = RawKeyboard._();

  final List<ValueChanged<RawKeyEvent>> _listeners = <ValueChanged<RawKeyEvent>>[];

  /// Register a listener that is called every time the user presses or releases
  /// a hardware keyboard key.
  ///
  /// Since the listeners have no way to indicate what they did with the event,
  /// listeners are assumed to not handle the key event. These events will also
  /// be distributed to other listeners, and to the [keyEventHandler].
  ///
  /// Most applications prefer to use the focus system (see [Focus] and
  /// [FocusManager]) to receive key events to the focused control instead of
  /// this kind of passive listener.
  ///
  /// Listeners can be removed with [removeListener].
  void addListener(ValueChanged<RawKeyEvent> listener) {
    _listeners.add(listener);
  }

  /// Stop calling the given listener every time the user presses or releases a
  /// hardware keyboard key.
  ///
  /// Listeners can be added with [addListener].
  void removeListener(ValueChanged<RawKeyEvent> listener) {
    _listeners.remove(listener);
  }

  /// A handler for raw hardware keyboard events that will stop propagation if
  /// the handler returns true.
  ///
  /// This property is only a wrapper over [KeyEventManager.keyMessageHandler],
  /// and is kept only for backward compatibility. New code should use
  /// [KeyEventManager.keyMessageHandler] to set custom global key event
  /// handler.  Setting [keyEventHandler] will cause
  /// [KeyEventManager.keyMessageHandler] to be set with a converted handler.
  /// If [KeyEventManager.keyMessageHandler] is set by [FocusManager] (the most
  /// common situation), then the exact value of [keyEventHandler] is a dummy
  /// callback and must not be invoked.
  RawKeyEventHandler? get keyEventHandler {
    if (ServicesBinding.instance!.keyEventManager.keyMessageHandler != _cachedKeyMessageHandler) {
      _cachedKeyMessageHandler = ServicesBinding.instance!.keyEventManager.keyMessageHandler;
      _cachedKeyEventHandler = _cachedKeyMessageHandler == null ?
        null :
        (RawKeyEvent event) {
          assert(false,
              'The RawKeyboard.instance.keyEventHandler assigned by Flutter is a dummy '
              'callback kept for compatibility and should not be directly called. Use '
              'ServicesBinding.instance!.keyMessageHandler instead.');
          return true;
        };
    }
    return _cachedKeyEventHandler;
  }
  RawKeyEventHandler? _cachedKeyEventHandler;
  KeyMessageHandler? _cachedKeyMessageHandler;
  set keyEventHandler(RawKeyEventHandler? handler) {
    _cachedKeyEventHandler = handler;
    _cachedKeyMessageHandler = handler == null ?
      null :
      (KeyMessage message) => handler(message.rawEvent);
    ServicesBinding.instance!.keyEventManager.keyMessageHandler = _cachedKeyMessageHandler;
  }

  /// Process a new [RawKeyEvent] by recording the state changes and
  /// dispatching to listeners.
  bool handleRawKeyEvent(RawKeyEvent event) {
    bool shouldDispatch = true;
    if (event is RawKeyDownEvent) {
      if (event.data.shouldDispatchEvent()) {
        _keysPressed[event.physicalKey] = event.logicalKey;
      } else {
        shouldDispatch = false;
        _hiddenKeysPressed.add(event.physicalKey);
      }
    } else if (event is RawKeyUpEvent) {
      if (!_hiddenKeysPressed.contains(event.physicalKey)) {
        // Use the physical key in the key up event to find the physical key from
        // the corresponding key down event and remove it, even if the logical
        // keys don't match.
        _keysPressed.remove(event.physicalKey);
      } else {
        _hiddenKeysPressed.remove(event.physicalKey);
        shouldDispatch = false;
      }
    }
    if (!shouldDispatch) {
      return true;
    }
    // Make sure that the modifiers reflect reality, in case a modifier key was
    // pressed/released while the app didn't have focus.
    _synchronizeModifiers(event);
    assert(
      event is! RawKeyDownEvent || _keysPressed.isNotEmpty,
      'Attempted to send a key down event when no keys are in keysPressed. '
      "This state can occur if the key event being sent doesn't properly "
      'set its modifier flags. This was the event: $event and its data: '
      '${event.data}',
    );
    // Send the event to passive listeners.
    for (final ValueChanged<RawKeyEvent> listener in List<ValueChanged<RawKeyEvent>>.from(_listeners)) {
      if (_listeners.contains(listener)) {
        listener(event);
      }
    }

    return false;
  }

  static final Map<_ModifierSidePair, Set<PhysicalKeyboardKey>> _modifierKeyMap = <_ModifierSidePair, Set<PhysicalKeyboardKey>>{
    const _ModifierSidePair(ModifierKey.altModifier, KeyboardSide.left): <PhysicalKeyboardKey>{PhysicalKeyboardKey.altLeft},
    const _ModifierSidePair(ModifierKey.altModifier, KeyboardSide.right): <PhysicalKeyboardKey>{PhysicalKeyboardKey.altRight},
    const _ModifierSidePair(ModifierKey.altModifier, KeyboardSide.all): <PhysicalKeyboardKey>{PhysicalKeyboardKey.altLeft, PhysicalKeyboardKey.altRight},
    const _ModifierSidePair(ModifierKey.altModifier, KeyboardSide.any): <PhysicalKeyboardKey>{PhysicalKeyboardKey.altLeft},
    const _ModifierSidePair(ModifierKey.shiftModifier, KeyboardSide.left): <PhysicalKeyboardKey>{PhysicalKeyboardKey.shiftLeft},
    const _ModifierSidePair(ModifierKey.shiftModifier, KeyboardSide.right): <PhysicalKeyboardKey>{PhysicalKeyboardKey.shiftRight},
    const _ModifierSidePair(ModifierKey.shiftModifier, KeyboardSide.all): <PhysicalKeyboardKey>{PhysicalKeyboardKey.shiftLeft, PhysicalKeyboardKey.shiftRight},
    const _ModifierSidePair(ModifierKey.shiftModifier, KeyboardSide.any): <PhysicalKeyboardKey>{PhysicalKeyboardKey.shiftLeft},
    const _ModifierSidePair(ModifierKey.controlModifier, KeyboardSide.left): <PhysicalKeyboardKey>{PhysicalKeyboardKey.controlLeft},
    const _ModifierSidePair(ModifierKey.controlModifier, KeyboardSide.right): <PhysicalKeyboardKey>{PhysicalKeyboardKey.controlRight},
    const _ModifierSidePair(ModifierKey.controlModifier, KeyboardSide.all): <PhysicalKeyboardKey>{PhysicalKeyboardKey.controlLeft, PhysicalKeyboardKey.controlRight},
    const _ModifierSidePair(ModifierKey.controlModifier, KeyboardSide.any): <PhysicalKeyboardKey>{PhysicalKeyboardKey.controlLeft},
    const _ModifierSidePair(ModifierKey.metaModifier, KeyboardSide.left): <PhysicalKeyboardKey>{PhysicalKeyboardKey.metaLeft},
    const _ModifierSidePair(ModifierKey.metaModifier, KeyboardSide.right): <PhysicalKeyboardKey>{PhysicalKeyboardKey.metaRight},
    const _ModifierSidePair(ModifierKey.metaModifier, KeyboardSide.all): <PhysicalKeyboardKey>{PhysicalKeyboardKey.metaLeft, PhysicalKeyboardKey.metaRight},
    const _ModifierSidePair(ModifierKey.metaModifier, KeyboardSide.any): <PhysicalKeyboardKey>{PhysicalKeyboardKey.metaLeft},
    const _ModifierSidePair(ModifierKey.capsLockModifier, KeyboardSide.all): <PhysicalKeyboardKey>{PhysicalKeyboardKey.capsLock},
    const _ModifierSidePair(ModifierKey.numLockModifier, KeyboardSide.all): <PhysicalKeyboardKey>{PhysicalKeyboardKey.numLock},
    const _ModifierSidePair(ModifierKey.scrollLockModifier, KeyboardSide.all): <PhysicalKeyboardKey>{PhysicalKeyboardKey.scrollLock},
    const _ModifierSidePair(ModifierKey.functionModifier, KeyboardSide.all): <PhysicalKeyboardKey>{PhysicalKeyboardKey.fn},
    // The symbolModifier doesn't have a key representation on any of the
    // platforms, so don't map it here.
  };

  // The map of all modifier keys except Fn, since that is treated differently
  // on some platforms.
  static final Map<PhysicalKeyboardKey, LogicalKeyboardKey> _allModifiersExceptFn = <PhysicalKeyboardKey, LogicalKeyboardKey>{
    PhysicalKeyboardKey.altLeft: LogicalKeyboardKey.altLeft,
    PhysicalKeyboardKey.altRight: LogicalKeyboardKey.altRight,
    PhysicalKeyboardKey.shiftLeft: LogicalKeyboardKey.shiftLeft,
    PhysicalKeyboardKey.shiftRight: LogicalKeyboardKey.shiftRight,
    PhysicalKeyboardKey.controlLeft: LogicalKeyboardKey.controlLeft,
    PhysicalKeyboardKey.controlRight: LogicalKeyboardKey.controlRight,
    PhysicalKeyboardKey.metaLeft: LogicalKeyboardKey.metaLeft,
    PhysicalKeyboardKey.metaRight: LogicalKeyboardKey.metaRight,
    PhysicalKeyboardKey.capsLock: LogicalKeyboardKey.capsLock,
    PhysicalKeyboardKey.numLock: LogicalKeyboardKey.numLock,
    PhysicalKeyboardKey.scrollLock: LogicalKeyboardKey.scrollLock,
  };

  // The map of all modifier keys that are represented in modifier key bit
  // masks on all platforms, so that they can be cleared out of pressedKeys when
  // synchronizing.
  static final Map<PhysicalKeyboardKey, LogicalKeyboardKey> _allModifiers = <PhysicalKeyboardKey, LogicalKeyboardKey>{
    PhysicalKeyboardKey.fn: LogicalKeyboardKey.fn,
    ..._allModifiersExceptFn,
  };

  void _synchronizeModifiers(RawKeyEvent event) {
    // Compare modifier states to the ground truth as specified by
    // [RawKeyEvent.data.modifiersPressed] and update unsynchronized ones.
    //
    // This function will update the state of modifier keys in `_keysPressed` so
    // that they match the ones given by [RawKeyEvent.data.modifiersPressed].
    // For a `modifiersPressed` result of anything but [KeyboardSide.any], the
    // states in `_keysPressed` will be updated to exactly match the result,
    // i.e. exactly one of "no down", "left down", "right down" or "both down".
    //
    // If `modifiersPressed` returns [KeyboardSide.any], the states in
    // `_keysPressed` will be updated to a rough match, i.e. "either side down"
    // or "no down". If `_keysPressed` has no modifier down, a
    // [KeyboardSide.any] will synchronize by forcing the left modifier down. If
    // `_keysPressed` has any modifier down, a [KeyboardSide.any] will not cause
    // a state change.

    final Map<ModifierKey, KeyboardSide?> modifiersPressed = event.data.modifiersPressed;
    final Map<PhysicalKeyboardKey, LogicalKeyboardKey> modifierKeys = <PhysicalKeyboardKey, LogicalKeyboardKey>{};
    // Physical keys that whose modifiers are pressed at any side.
    final Set<PhysicalKeyboardKey> anySideKeys = <PhysicalKeyboardKey>{};
    final Set<PhysicalKeyboardKey> keysPressedAfterEvent = <PhysicalKeyboardKey>{
      ..._keysPressed.keys,
      if (event is RawKeyDownEvent) event.physicalKey,
    };
    for (final ModifierKey key in modifiersPressed.keys) {
      if (modifiersPressed[key] == KeyboardSide.any) {
        final Set<PhysicalKeyboardKey>? thisModifierKeys = _modifierKeyMap[_ModifierSidePair(key, KeyboardSide.all)];
        anySideKeys.addAll(thisModifierKeys!);
        if (thisModifierKeys.any(keysPressedAfterEvent.contains)) {
          continue;
        }
      }
      final Set<PhysicalKeyboardKey>? mappedKeys = _modifierKeyMap[_ModifierSidePair(key, modifiersPressed[key])];
      assert(() {
        if (mappedKeys == null) {
          debugPrint(
            'Platform key support for ${Platform.operatingSystem} is '
            'producing unsupported modifier combinations for '
            'modifier $key on side ${modifiersPressed[key]}.',
          );
          if (event.data is RawKeyEventDataAndroid) {
            debugPrint('Android raw key metaState: ${(event.data as RawKeyEventDataAndroid).metaState}');
          }
        }
        return true;
      }());
      if (mappedKeys == null) {
        continue;
      }
      for (final PhysicalKeyboardKey physicalModifier in mappedKeys) {
        modifierKeys[physicalModifier] = _allModifiers[physicalModifier]!;
      }
    }
    _allModifiersExceptFn.keys
      .where((PhysicalKeyboardKey key) => !anySideKeys.contains(key))
      .forEach(_keysPressed.remove);
    if (event.data is! RawKeyEventDataFuchsia && event.data is! RawKeyEventDataMacOs) {
      // On Fuchsia and macOS, the Fn key is not considered a modifier key.
      _keysPressed.remove(PhysicalKeyboardKey.fn);
    }
    _keysPressed.addAll(modifierKeys);
  }

  final Map<PhysicalKeyboardKey, LogicalKeyboardKey> _keysPressed = <PhysicalKeyboardKey, LogicalKeyboardKey>{};
  final Set<PhysicalKeyboardKey> _hiddenKeysPressed = <PhysicalKeyboardKey>{};

  /// Returns the set of keys currently pressed.
  Set<LogicalKeyboardKey> get keysPressed => _keysPressed.values.toSet();

  /// Returns the set of physical keys currently pressed.
  Set<PhysicalKeyboardKey> get physicalKeysPressed => _keysPressed.keys.toSet();

  /// Returns the logical key that corresponds to the given pressed physical key.
  ///
  /// Returns null if the physical key is not currently pressed.
  LogicalKeyboardKey? lookUpLayout(PhysicalKeyboardKey physicalKey) => _keysPressed[physicalKey];

  /// Clears the list of keys returned from [keysPressed].
  ///
  /// This is used by the testing framework to make sure tests are hermetic.
  @visibleForTesting
  void clearKeysPressed() => _keysPressed.clear();
}

@immutable
class _ModifierSidePair {
  const _ModifierSidePair(this.modifier, this.side);

  final ModifierKey modifier;
  final KeyboardSide? side;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType)
      return false;
    return other is _ModifierSidePair
        && other.modifier == modifier
        && other.side == side;
  }

  @override
  int get hashCode => ui.hashValues(modifier, side);
}
