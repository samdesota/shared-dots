import {
  FromEvent,
  FromKeyCode,
  hyperLayer,
  layer,
  map,
  rule,
  writeToProfile,
} from "karabiner.ts";

const comfyMods = () => {
  return [
    ...makeHalfManipulators("left", ["f", "d", "s", "a", "spacebar"]),
    ...makeHalfManipulators("right", ["j", "k", "l", "semicolon", "spacebar"]),
  ];

  function makeHalfManipulators(
    side: "left" | "right",
    modKeys: FromKeyCode[],
  ) {
    return [
      ...makeModManipulators({
        pair: [0, 1],
        mod: "command",
        otherMods: {
          2: "control",
          3: "option",
          4: "shift",
        },
      }),

      ...makeModManipulators({
        pair: [1, 2],
        mod: "control",
        otherMods: {
          0: "command",
          3: "option",
          4: "shift",
        },
      }),

      ...makeModManipulators({
        pair: [2, 3],
        mod: "option",
        otherMods: {
          0: "command",
          1: "control",
          4: "shift",
        },
      }),
    ];

    function makeModManipulators(mapping: {
      pair: [number, number];
      mod: "control" | "command" | "option" | "shift";
      otherMods: { [key: number]: "control" | "command" | "option" | "shift" };
    }) {
      const pair = mapping.pair.map((i) => ({ key_code: modKeys[i] }));
      const mod = `${side}_${mapping.mod}`;

      return [
        map({
          simultaneous: pair,
          simultaneous_options: {
            detect_key_down_uninterruptedly: true,
            key_down_order: "insensitive",
            key_up_order: "insensitive",
            key_up_when: "any",
            to_after_key_up: [
              {
                set_variable: {
                  name: "comfy_mods",
                  value: 0,
                },
              },
            ],
          },
        })
          .to({ set_variable: { name: "comfy_mods", value: mod } })
          .to(`${side}_${mapping.mod}`),

        ...Object.entries(mapping.otherMods).map(([key, value]) =>
          map({
            key_code: modKeys[Number(key)],
            modifiers: { optional: ["any"] },
          })
            .condition({
              name: "comfy_mods",
              type: "variable_if",
              value: mod,
            })
            .to(`${side}_${value}`),
        ),
      ];
    }
  }
};

function anymod(key: FromKeyCode): FromEvent {
  return {
    key_code: key,
    modifiers: { optional: ["any"] },
  };
}

const wisprFlowShortcut = { key_code: "f18", modifiers: ["right_control"] };
const mediaControl = `${process.cwd()}/fn-media-control.sh`;
const vocalCommanderStateFile = "/tmp/karabiner-vocal-commander-listening";
const vocalCommanderListen = `/bin/zsh -lc 'vocal-commander listen && touch ${vocalCommanderStateFile}'`;
const vocalCommanderStop = `/bin/zsh -lc 'if [ -f ${vocalCommanderStateFile} ]; then vocal-commander stop-listening; rm -f ${vocalCommanderStateFile}; fi'`;
const wisprFlowTap = [
  { shell_command: `${mediaControl} tap-before` },
  wisprFlowShortcut,
  { shell_command: `${mediaControl} tap-after` },
];
const vocalCommanderHold = [
  { shell_command: `${mediaControl} pause-hold` },
  { shell_command: vocalCommanderListen },
];
const vocalCommanderAfterKeyUp = [
  {
    shell_command: `/bin/zsh -lc 'if [ -f ${vocalCommanderStateFile} ]; then vocal-commander stop-listening; rm -f ${vocalCommanderStateFile}; ${mediaControl} resume-hold; fi'`,
  },
];
const dictationTriggerDown = {
  set_variable: { name: "dictation_trigger_down", value: 1 },
};
const tapOrHoldParameters = {
  "basic.to_if_alone_timeout_milliseconds": 1000,
  "basic.to_if_held_down_threshold_milliseconds": 500,
};

writeToProfile("redux", [
  rule("Tap Fn -> Wispr Flow, hold Fn -> Vocal Commander").manipulators([
    {
      type: "basic",
      parameters: tapOrHoldParameters,
      from: {
        apple_vendor_top_case_key_code: "keyboard_fn",
        modifiers: { optional: ["any"] },
      },
      to: [dictationTriggerDown],
      to_if_alone: wisprFlowTap,
      to_if_held_down: vocalCommanderHold,
      to_after_key_up: vocalCommanderAfterKeyUp,
    } as any,
  ]),

  rule("Tap right click -> Wispr Flow, hold right click -> Vocal Commander").manipulators([
    {
      type: "basic",
      parameters: tapOrHoldParameters,
      from: {
        pointing_button: "button2",
        modifiers: { optional: ["any"] },
      },
      to: [dictationTriggerDown],
      to_if_alone: wisprFlowTap,
      to_if_held_down: vocalCommanderHold,
      to_after_key_up: vocalCommanderAfterKeyUp,
    } as any,
  ]),

  rule("Middle mouse -> Right click").manipulators([
    {
      type: "basic",
      from: {
        pointing_button: "button3",
        modifiers: { optional: ["any"] },
      },
      to: [{ pointing_button: "button2" }],
    } as any,
  ]),

  rule("Mouse button5 -> Enter").manipulators([
    {
      type: "basic",
      from: {
        pointing_button: "button5",
        modifiers: { optional: ["any"] },
      },
      to: [{ key_code: "return_or_enter" }],
    } as any,
  ]),

  rule("Caps -> Hyper").manipulators([
    // config key mapping
    map("caps_lock").to("left_control", [
      "left_command",
      "left_shift",
      "left_option",
    ]),
    map("left_shift").toIfAlone("escape").to("left_shift"),
    map("right_shift")
      .toIfAlone({
        key_code: "l",
        modifiers: ["right_option", "right_command"],
      })
      .to("right_shift"),
  ]),

  layer("semicolon", "navigation-mode").manipulators([
    map(anymod("h")).to("left_arrow"),
    map(anymod("j")).to("down_arrow"),
    map(anymod("k")).to("up_arrow"),
    map(anymod("l")).to("right_arrow"),
  ]),

  layer("quote", "spanish-letters").manipulators([
    // Vowels with acute accents (using Option key combinations that work on macOS)
    map(anymod("a")).to([
      { key_code: "e", modifiers: ["option"] }, // ´ accent
      { key_code: "a" }, // a = á
    ]),
    map(anymod("e")).to([
      { key_code: "e", modifiers: ["option"] }, // ´ accent
      { key_code: "e" }, // e = é
    ]),
    map(anymod("i")).to([
      { key_code: "e", modifiers: ["option"] }, // ´ accent
      { key_code: "i" }, // i = í
    ]),
    map(anymod("o")).to([
      { key_code: "e", modifiers: ["option"] }, // ´ accent
      { key_code: "o" }, // o = ó
    ]),
    map(anymod("u")).to([
      { key_code: "e", modifiers: ["option"] }, // ´ accent
      { key_code: "u" }, // u = ú
    ]),

    // Special Spanish letters
    map(anymod("n")).to([
      { key_code: "n", modifiers: ["option"] }, // ˜ tilde
      { key_code: "n" }, // n = ñ
    ]),

    // Capital vowels with acute accents (with shift)
    map({ key_code: "a", modifiers: { mandatory: ["shift"] } }).to([
      { key_code: "e", modifiers: ["option"] }, // ´ accent
      { key_code: "a", modifiers: ["shift"] }, // A = Á
    ]),
    map({ key_code: "e", modifiers: { mandatory: ["shift"] } }).to([
      { key_code: "e", modifiers: ["option"] }, // ´ accent
      { key_code: "e", modifiers: ["shift"] }, // E = É
    ]),
    map({ key_code: "i", modifiers: { mandatory: ["shift"] } }).to([
      { key_code: "e", modifiers: ["option"] }, // ´ accent
      { key_code: "i", modifiers: ["shift"] }, // I = Í
    ]),
    map({ key_code: "o", modifiers: { mandatory: ["shift"] } }).to([
      { key_code: "e", modifiers: ["option"] }, // ´ accent
      { key_code: "o", modifiers: ["shift"] }, // O = Ó
    ]),
    map({ key_code: "u", modifiers: { mandatory: ["shift"] } }).to([
      { key_code: "e", modifiers: ["option"] }, // ´ accent
      { key_code: "u", modifiers: ["shift"] }, // U = Ú
    ]),

    // Capital special letters (with shift)
    map({ key_code: "n", modifiers: { mandatory: ["shift"] } }).to([
      { key_code: "n", modifiers: ["option"] }, // ˜ tilde
      { key_code: "n", modifiers: ["shift"] }, // N = Ñ
    ]),

    // u with diaeresis (umlaut) - using Option+u combination
    map(anymod("y")).to([
      { key_code: "u", modifiers: ["option"] }, // ¨ diaeresis
      { key_code: "u" }, // u = ü
    ]),
    map({ key_code: "y", modifiers: { mandatory: ["shift"] } }).to([
      { key_code: "u", modifiers: ["option"] }, // ¨ diaeresis
      { key_code: "u", modifiers: ["shift"] }, // U = Ü
    ]),

    // Inverted punctuation marks
    map(anymod("1")).to("1", "option"), // ¡
    map(anymod("slash")).to("slash", ["shift", "option"]), // ¿
  ]),

  rule("comfy mods").manipulators([...comfyMods()]),
]);
