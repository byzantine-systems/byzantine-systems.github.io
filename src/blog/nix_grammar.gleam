//// Smalto grammar for the Nix expression language.
////
//// Neither smalto nor blogatto ship one, so it is registered in `blog.gleam`
//// via `code.add_language`. Loosely ported from Prism's `nix` grammar, with
//// two changes: Prism-only token names (`boolean`, `url`, `antiquotation`)
//// are mapped onto smalto's built-in ones so the default theme styles them,
//// and attribute names (`foo.bar =`) are highlighted as properties.

import gleam/option
import smalto/grammar.{type Grammar, type Rule, Grammar}

/// Returns the Nix language grammar.
pub fn grammar() -> Grammar {
  Grammar(name: "nix", extends: option.None, rules: rules())
}

fn rules() -> List(Rule) {
  [
    grammar.greedy_rule("comment", "\\/\\*[\\s\\S]*?\\*\\/|#.*"),
    // Rules with `inside` emit only what their inner rules match, so the
    // catch-all `string` rule keeps the non-interpolated text styled.
    grammar.greedy_rule_with_inside(
      "string",
      "\"(?:[^\"\\\\]|\\\\[\\s\\S])*\"|''(?:(?!'')[\\s\\S]|''(?:'|\\\\|\\$\\{))*''",
      [interpolation(), grammar.rule("string", "[\\s\\S]+")],
    ),
    grammar.greedy_rule(
      "string",
      "\\b[a-z][a-z0-9+.-]*:\\/\\/[\\w\\-+%~\\/.:#=?&@]+",
    ),
    // Search paths (`<nixpkgs>`) and literal paths (`./.`, `~/x`, `a/b`).
    grammar.rule("string", "<[\\w.+-]+(?:\\/[\\w.+-]+)*>"),
    grammar.rule(
      "string",
      "(?<![\\w\\/.+'-])(?:~|[\\w.+-]*)(?:\\/[\\w.+-]+)+\\/?",
    ),
    ..expression_rules()
  ]
}

/// `${ ... }` inside a string. Nested strings are not tokenized again: rule
/// lists are built eagerly, so referencing `rules()` here would never end.
fn interpolation() -> Rule {
  grammar.rule_with_inside(
    "interpolation",
    "(?:^|[^\\\\'$])\\K\\$\\{(?:[^{}]|\\{[^}]*\\})*\\}",
    [grammar.rule("string", "\"(?:[^\"\\\\]|\\\\.)*\""), ..expression_rules()],
  )
}

fn expression_rules() -> List(Rule) {
  [
    grammar.rule("punctuation", "\\$(?=\\{)"),
    grammar.rule("number", "\\b\\d+(?:\\.\\d+)?\\b"),
    grammar.rule(
      "keyword",
      "\\b(?:assert|else|if|in|inherit|let|or|rec|then|with)\\b",
    ),
    grammar.rule("constant", "\\b(?:false|null|true)\\b"),
    grammar.rule(
      "property",
      "\\b[A-Za-z_][\\w'-]*(?:\\.[A-Za-z_][\\w'-]*)*(?=\\s*=(?!=))",
    ),
    grammar.rule(
      "builtin",
      "\\b(?:abort|baseNameOf|builtins|derivation|dirOf|fetchGit|fetchTarball|fetchurl|import|isNull|map|placeholder|removeAttrs|throw|toString)\\b",
    ),
    // Nix identifiers may contain `-` and `'` (`nix-gleam`, `inputs'`); claim
    // them before `-` is read as an operator. Unknown token names render as
    // plain text.
    grammar.rule("identifier", "\\b[A-Za-z_][\\w'-]*"),
    grammar.rule("operator", "[=!<>]=?|\\+\\+?|\\|\\||&&|\\/\\/|->?|[?@*\\/]"),
    grammar.rule("punctuation", "[{}()\\[\\].,:;]"),
  ]
}
