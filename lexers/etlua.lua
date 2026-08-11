-- Copyright 2006-2025 Mitchell. See LICENSE.
-- etlua LPeg lexer.

local lexer = lexer
local P, S = lpeg.P, lpeg.S

local lex = lexer.new(..., {inherit = lexer.load('html')})

-- Embedded Lua
local lua = lexer.load('lua')
local start_rule = lex:tag(lexer.PREPROCESSOR, '<%' * (P('=') + P('-'))^-1)
local end_rule = lex:tag(lexer.PREPROCESSOR, P('-')^-1 * '%>')
lex:embed(lua, start_rule, end_rule)

return lex

