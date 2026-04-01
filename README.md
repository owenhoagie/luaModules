# luaModules

A collection of modules written in Luau, intended to be used in Roblox to aid creation.

## Modules

### `WebhookManager`

Builder module: `src/WebhookManager.lua`

Documentation and usage example: `src/WebhookManagerExample.lua`

### `ObjectUtils`

Utility module: `src/ObjectUtils.lua`

### `TextContrast`

Utility module for choosing white or black text from a background `Color3`: `src/TextContrast.lua`

### `PercentageTextAnimator`

Utility module for easing a `TextLabel` from `0.00 %` to a target percentage: `src/PercentageTextAnimator.lua`

Documentation and usage example: `src/PercentageTextAnimatorExample.lua`

### `ColorSimilarityScorer`

Color similarity module based on Dialed's public scoring breakdown: `src/ColorSimilarityScorer.lua`

Accepts normalized decimal HSB values (`0-1`) such as `H = 0.42, S = 0.77, B = 0.24`

Documentation and usage example: `src/ColorSimilarityScorerExample.lua`

### `MessagingManager`

Shared server/client chat messenger: `src/MessagingManager.lua`

Documentation and usage example: `src/MessagingManagerExample.lua`

### `WhitelistManager`

Server-side whitelist module: `src/WhitelistManager.lua`
