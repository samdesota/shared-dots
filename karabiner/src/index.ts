import {
  FromEvent,
  FromKeyCode,
  FromKeyType,
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

// ! Change '--dry-run' to your Karabiner-Elements Profile name.
// (--dry-run print the config json into console)
// + Create a new profile if needed.
writeToProfile("redux", [
  // It is not required, but recommended to put symbol alias to layers,
  // (If you type fast, use simlayer instead, see https://evan-liu.github.io/karabiner.ts/rules/simlayer)
  // to make it easier to write '←' instead of 'left_arrow'.
  // Supported alias: https://github.com/evan-liu/karabiner.ts/blob/main/src/utils/key-alias.ts
  // layer('/', 'symbol-mode').manipulators([
  //   //     / + [ 1    2    3    4    5 ] =>
  //   withMapper(['⌘', '⌥', '⌃', '⇧', '⇪'])((k, i) =>
  //     map((i + 1) as NumberKeyValue).toPaste(k),
  //   ),
  //   withMapper(['←', '→', '↑', '↓', '␣', '⏎', '⇥', '⎋', '⌫', '⌦', '⇪'])((k) =>
  //     map(k).toPaste(k),
  //   ),
  // ]),

  rule("Caps -> Hyper").manipulators([
    // config key mapping
    map("caps_lock").to("left_control", [
      "left_command",
      "left_shift",
      "left_option",
    ]),
    map("left_shift").toIfAlone("escape").to("left_shift"),
  ]),

  rule("layers").manipulators([
    map({
      simultaneous: [{ key_code: "e" }, { key_code: "r" }],
      simultaneous_options: {
        detect_key_down_uninterruptedly: true,
        key_down_order: "insensitive",
        key_up_order: "insensitive",
        key_up_when: "any",
        to_after_key_up: [
          {
            set_variable: {
              name: "nav-layer",
              value: 0,
            },
          },
        ],
      },
    }).to({
      set_variable: { name: "nav-layer", value: 1 },
    }),

    ...[
      map(anymod("h")).to("left_arrow"),
      map(anymod("j")).to("down_arrow"),
      map(anymod("k")).to("up_arrow"),
      map(anymod("l")).to("right_arrow"),
    ].map((m) =>
      m.condition({
        name: "nav-layer",
        type: "variable_if",
        value: 1,
      }),
    ),
  ]),

  rule("comfy mods").manipulators([...comfyMods()]),
]);
