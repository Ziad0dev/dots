" HAIL SATAN - A dark blood red occult theme for Neovim
" Author: Claude AI

highlight clear
if exists('syntax_on')
  syntax reset
endif

let g:colors_name = 'satan_theme'

" Color Definitions
" ----------------
" Dark blood red background
let s:bg0 = '#120000'
let s:bg1 = '#1D0000'
let s:bg2 = '#2A0000'
let s:bg3 = '#3A0000'
let s:bg4 = '#4A0000'

" Blood red foregrounds
let s:fg0 = '#FF9999'
let s:fg1 = '#FF6666'
let s:fg2 = '#FF3333'
let s:fg3 = '#FF0000'
let s:fg4 = '#CC0000'

" Accent colors
let s:red = '#FF0000'
let s:blood = '#8B0000'
let s:crimson = '#DC143C'
let s:pentagram = '#AA0000'
let s:ritual = '#660000'
let s:smoke = '#442222'
let s:bone = '#EECCCC'
let s:chalk = '#FFAAAA'
let s:candle = '#FF3300'

" General UI
" ----------------
exe 'hi Normal guifg='.s:fg0.' guibg='.s:bg0
exe 'hi NonText guifg='.s:smoke
exe 'hi Cursor guifg='.s:bg0.' guibg='.s:fg0
exe 'hi CursorLine guibg='.s:bg1.' gui=NONE'
exe 'hi CursorColumn guibg='.s:bg1
exe 'hi ColorColumn guibg='.s:bg1
exe 'hi LineNr guifg='.s:pentagram.' guibg='.s:bg0
exe 'hi CursorLineNr guifg='.s:candle.' guibg='.s:bg1.' gui=NONE'
exe 'hi VertSplit guifg='.s:bg3.' guibg='.s:bg0.' gui=NONE'
exe 'hi MatchParen guifg='.s:candle.' guibg='.s:bg0.' gui=underline'
exe 'hi StatusLine guifg='.s:fg0.' guibg='.s:bg2.' gui=NONE'
exe 'hi StatusLineNC guifg='.s:smoke.' guibg='.s:bg1.' gui=NONE'
exe 'hi Pmenu guifg='.s:fg0.' guibg='.s:bg1
exe 'hi PmenuSel guifg='.s:bg0.' guibg='.s:red
exe 'hi PmenuSbar guibg='.s:bg2
exe 'hi PmenuThumb guibg='.s:crimson
exe 'hi IncSearch guifg='.s:bg0.' guibg='.s:candle.' gui=NONE'
exe 'hi Search guifg='.s:bg0.' guibg='.s:pentagram
exe 'hi Directory guifg='.s:crimson
exe 'hi Folded guifg='.s:smoke.' guibg='.s:bg0
exe 'hi Visual guibg='.s:bg3.' gui=NONE'
exe 'hi SpellBad guifg='.s:red.' gui=undercurl'
exe 'hi SpellCap guifg='.s:candle.' gui=undercurl'

" Syntax
" ----------------
exe 'hi Boolean guifg='.s:crimson
exe 'hi Character guifg='.s:crimson
exe 'hi Comment guifg='.s:smoke.' gui=italic'
exe 'hi Conditional guifg='.s:red
exe 'hi Constant guifg='.s:crimson
exe 'hi Define guifg='.s:red.' gui=NONE'
exe 'hi Delimiter guifg='.s:fg4
exe 'hi Float guifg='.s:crimson
exe 'hi Function guifg='.s:chalk
exe 'hi Identifier guifg='.s:fg1.' gui=NONE'
exe 'hi Include guifg='.s:red
exe 'hi Keyword guifg='.s:red.' gui=NONE'
exe 'hi Label guifg='.s:candle
exe 'hi Number guifg='.s:crimson
exe 'hi Operator guifg='.s:fg0.' gui=NONE'
exe 'hi PreProc guifg='.s:candle
exe 'hi Repeat guifg='.s:red
exe 'hi Special guifg='.s:crimson
exe 'hi SpecialChar guifg='.s:fg4
exe 'hi SpecialComment guifg='.s:smoke.' gui=italic'
exe 'hi Statement guifg='.s:red.' gui=NONE'
exe 'hi StorageClass guifg='.s:candle
exe 'hi String guifg='.s:pentagram
exe 'hi Structure guifg='.s:red
exe 'hi Tag guifg='.s:candle
exe 'hi Todo guifg='.s:candle.' guibg='.s:bg0.' gui=bold'
exe 'hi Type guifg='.s:candle.' gui=NONE'
exe 'hi Typedef guifg='.s:candle

" Diff highlighting
exe 'hi DiffAdd guifg='.s:chalk.' guibg='.s:ritual.' gui=NONE'
exe 'hi DiffChange guifg='.s:smoke.' guibg='.s:bg0.' gui=NONE'
exe 'hi DiffDelete guifg='.s:red.' guibg='.s:ritual.' gui=NONE'
exe 'hi DiffText guifg='.s:chalk.' guibg='.s:blood.' gui=bold'

" GitGutter highlighting
exe 'hi GitGutterAdd guifg='.s:ritual.' guibg='.s:bg0
exe 'hi GitGutterChange guifg='.s:candle.' guibg='.s:bg0
exe 'hi GitGutterDelete guifg='.s:red.' guibg='.s:bg0
exe 'hi GitGutterChangeDelete guifg='.s:crimson.' guibg='.s:bg0

" NERDTree highlighting
exe 'hi NERDTreeDirSlash guifg='.s:red
exe 'hi NERDTreeExecFile guifg='.s:fg0

" Extra blood red highlights
exe 'hi SpecialKey guifg='.s:crimson.' guibg=NONE gui=NONE'
exe 'hi Title guifg='.s:red.' guibg=NONE gui=bold'
exe 'hi Underlined guifg='.s:pentagram.' gui=underline'
exe 'hi ErrorMsg guifg='.s:red.' guibg='.s:bg0.' gui=bold'
exe 'hi WarningMsg guifg='.s:candle.' guibg='.s:bg0.' gui=bold'
exe 'hi SignColumn guibg='.s:bg0.' guifg='.s:red

" Customize signs for occult symbols
sign define DiagnosticSignError text=☠ texthl=DiagnosticSignError linehl= numhl=
sign define DiagnosticSignWarn text=⚠ texthl=DiagnosticSignWarn linehl= numhl=
sign define DiagnosticSignInfo text=⚡ texthl=DiagnosticSignInfo linehl= numhl=
sign define DiagnosticSignHint text=⚒ texthl=DiagnosticSignHint linehl= numhl= 