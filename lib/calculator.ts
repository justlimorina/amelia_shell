/**
 * Safe Mathematical Expression Parser
 * Evaluates arithmetic expressions without using `eval` or `new Function`.
 * Supports +, -, *, /, %, ^, parentheses, basic constants (pi, e), and functions.
 */

type TokenType = "NUMBER" | "OP" | "LPAREN" | "RPAREN" | "NAME"

interface Token {
  type: TokenType
  value: string | number
}

function tokenize(input: string): Token[] | null {
  const tokens: Token[] = []
  let i = 0
  const len = input.length

  while (i < len) {
    const ch = input[i]

    if (/\s/.test(ch)) {
      i++
      continue
    }

    if (/[0-9]/.test(ch) || (ch === "." && i + 1 < len && /[0-9]/.test(input[i + 1]))) {
      let numStr = ""
      while (i < len && (/[0-9]/.test(input[i]) || input[i] === ".")) {
        numStr += input[i]
        i++
      }
      const num = parseFloat(numStr)
      if (isNaN(num)) return null
      tokens.push({ type: "NUMBER", value: num })
      continue
    }

    if ("+-*/%^".includes(ch)) {
      tokens.push({ type: "OP", value: ch })
      i++
      continue
    }

    if (ch === "(") {
      tokens.push({ type: "LPAREN", value: "(" })
      i++
      continue
    }

    if (ch === ")") {
      tokens.push({ type: "RPAREN", value: ")" })
      i++
      continue
    }

    if (/[a-zA-Z_]/.test(ch)) {
      let name = ""
      while (i < len && /[a-zA-Z0-9_]/.test(input[i])) {
        name += input[i]
        i++
      }
      tokens.push({ type: "NAME", value: name.toLowerCase() })
      continue
    }

    // Unrecognized character
    return null
  }

  return tokens
}

export function evaluateSafeMath(input: string): string | null {
  const clean = input.trim()
  if (!clean) return null

  // Quick sanity check: must contain at least one digit or constant and one operator or function
  if (!/[0-9]|pi|e/i.test(clean)) return null

  const tokens = tokenize(clean)
  if (!tokens || tokens.length === 0) return null

  let pos = 0

  function peek(): Token | undefined {
    return tokens![pos]
  }

  function consume(): Token {
    return tokens![pos++]
  }

  function parseExpression(): number {
    let result = parseTerm()
    while (pos < tokens!.length) {
      const tok = peek()
      if (tok && tok.type === "OP" && (tok.value === "+" || tok.value === "-")) {
        consume()
        const right = parseTerm()
        result = tok.value === "+" ? result + right : result - right
      } else {
        break
      }
    }
    return result
  }

  function parseTerm(): number {
    let result = parsePower()
    while (pos < tokens!.length) {
      const tok = peek()
      if (tok && tok.type === "OP" && (tok.value === "*" || tok.value === "/" || tok.value === "%")) {
        consume()
        const right = parsePower()
        if (tok.value === "*") result *= right
        else if (tok.value === "/") {
          if (right === 0) throw new Error("Division by zero")
          result /= right
        } else {
          result %= right
        }
      } else {
        break
      }
    }
    return result
  }

  function parsePower(): number {
    const left = parseFactor()
    const tok = peek()
    if (tok && tok.type === "OP" && tok.value === "^") {
      consume()
      const right = parsePower() // right-associative
      return Math.pow(left, right)
    }
    return left
  }

  function parseFactor(): number {
    const tok = peek()
    if (!tok) throw new Error("Unexpected end of input")

    if (tok.type === "OP" && (tok.value === "+" || tok.value === "-")) {
      consume()
      const factor = parseFactor()
      return tok.value === "-" ? -factor : factor
    }

    return parsePrimary()
  }

  function parsePrimary(): number {
    const tok = consume()
    if (!tok) throw new Error("Unexpected end of input")

    if (tok.type === "NUMBER") {
      return tok.value as number
    }

    if (tok.type === "LPAREN") {
      const val = parseExpression()
      const next = consume()
      if (!next || next.type !== "RPAREN") {
        throw new Error("Missing closing parenthesis")
      }
      return val
    }

    if (tok.type === "NAME") {
      const name = tok.value as string
      if (name === "pi") return Math.PI
      if (name === "e") return Math.E

      // Function calls: sqrt, sin, cos, tan, abs, log, ln, round, floor, ceil
      const next = peek()
      if (next && next.type === "LPAREN") {
        consume() // consume '('
        const arg = parseExpression()
        const closing = consume()
        if (!closing || closing.type !== "RPAREN") {
          throw new Error("Missing closing parenthesis for function")
        }

        switch (name) {
          case "sqrt":
            return Math.sqrt(arg)
          case "sin":
            return Math.sin(arg)
          case "cos":
            return Math.cos(arg)
          case "tan":
            return Math.tan(arg)
          case "abs":
            return Math.abs(arg)
          case "log":
            return Math.log10(arg)
          case "ln":
            return Math.log(arg)
          case "round":
            return Math.round(arg)
          case "floor":
            return Math.floor(arg)
          case "ceil":
            return Math.ceil(arg)
          default:
            throw new Error(`Unknown function: ${name}`)
        }
      }

      throw new Error(`Unknown identifier: ${name}`)
    }

    throw new Error("Invalid syntax")
  }

  try {
    const result = parseExpression()
    if (pos < tokens.length) return null // Unconsumed tokens left
    if (typeof result === "number" && !isNaN(result) && isFinite(result)) {
      // Format clean decimals
      const rounded = Math.round(result * 1e10) / 1e10
      return String(rounded)
    }
  } catch (_) {
    return null
  }

  return null
}
