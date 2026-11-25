---
type: regex
target: last_message
# only the edited text: What changed may quote what was removed
pattern: '^(?:(?!What changed|Qu[eé] cambi)[\s\S])*?(?:panorama actual|cambio de paradigma|sin duda|desbloquea|todo el potencial)'
flags: i
match: not_contains
---
