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
exe 'hi Normal guifg='.s:fg0.' guibg='.s:bg0.' ctermfg=red ctermbg=black'
exe 'hi NonText guifg='.s:smoke.' ctermfg=darkgray'
exe 'hi Cursor guifg='.s:bg0.' guibg='.s:fg0
exe 'hi CursorLine guibg='.s:bg1.' gui=NONE ctermbg=NONE cterm=underline'
exe 'hi CursorColumn guibg='.s:bg1.' ctermbg=NONE'
exe 'hi ColorColumn guibg='.s:bg1.' ctermbg=NONE'
exe 'hi LineNr guifg='.s:pentagram.' guibg='.s:bg0.' ctermfg=darkred ctermbg=NONE'
exe 'hi CursorLineNr guifg='.s:candle.' guibg='.s:bg1.' gui=NONE ctermfg=red ctermbg=NONE cterm=NONE'
exe 'hi VertSplit guifg='.s:bg3.' guibg='.s:bg0.' gui=NONE ctermfg=darkgray ctermbg=black cterm=NONE'
exe 'hi MatchParen guifg='.s:candle.' guibg='.s:bg0.' gui=underline ctermfg=yellow ctermbg=NONE cterm=underline'
exe 'hi StatusLine guifg='.s:fg0.' guibg='.s:bg2.' gui=NONE ctermfg=red ctermbg=black cterm=bold'
exe 'hi StatusLineNC guifg='.s:smoke.' guibg='.s:bg1.' gui=NONE ctermfg=darkgray ctermbg=black cterm=NONE'
exe 'hi Pmenu guifg='.s:fg0.' guibg='.s:bg1.' ctermfg=red ctermbg=black'
exe 'hi PmenuSel guifg='.s:bg0.' guibg='.s:red.' ctermfg=black ctermbg=red'
exe 'hi PmenuSbar guibg='.s:bg2.' ctermbg=black'
exe 'hi PmenuThumb guibg='.s:crimson.' ctermbg=red'
exe 'hi IncSearch guifg='.s:bg0.' guibg='.s:candle.' gui=NONE ctermfg=black ctermbg=yellow cterm=NONE'
exe 'hi Search guifg='.s:bg0.' guibg='.s:pentagram.' ctermfg=black ctermbg=darkred'
exe 'hi Directory guifg='.s:crimson.' ctermfg=red'
exe 'hi Folded guifg='.s:smoke.' guibg='.s:bg0.' ctermfg=darkgray ctermbg=black'
exe 'hi Visual guibg='.s:bg3.' gui=NONE ctermbg=darkgray cterm=NONE'
exe 'hi SpellBad guifg='.s:red.' gui=undercurl ctermfg=red cterm=underline'
exe 'hi SpellCap guifg='.s:candle.' gui=undercurl ctermfg=yellow cterm=underline'

" Syntax
" ----------------
exe 'hi Boolean guifg='.s:crimson.' ctermfg=darkred'
exe 'hi Character guifg='.s:crimson.' ctermfg=darkred'
exe 'hi Comment guifg='.s:smoke.' gui=italic ctermfg=darkgray cterm=italic'
exe 'hi Conditional guifg='.s:red.' ctermfg=red'
exe 'hi Constant guifg='.s:crimson.' ctermfg=darkred'
exe 'hi Define guifg='.s:red.' gui=NONE ctermfg=red cterm=NONE'
exe 'hi Delimiter guifg='.s:fg4.' ctermfg=red'
exe 'hi Float guifg='.s:crimson.' ctermfg=darkred'
exe 'hi Function guifg='.s:chalk.' ctermfg=red'
exe 'hi Identifier guifg='.s:fg1.' gui=NONE ctermfg=red cterm=NONE'
exe 'hi Include guifg='.s:red.' ctermfg=red'
exe 'hi Keyword guifg='.s:red.' gui=NONE ctermfg=red cterm=NONE'
exe 'hi Label guifg='.s:candle.' ctermfg=yellow'
exe 'hi Number guifg='.s:crimson.' ctermfg=darkred'
exe 'hi Operator guifg='.s:fg0.' gui=NONE ctermfg=red cterm=NONE'
exe 'hi PreProc guifg='.s:candle.' ctermfg=yellow'
exe 'hi Repeat guifg='.s:red.' ctermfg=red'
exe 'hi Special guifg='.s:crimson.' ctermfg=darkred'
exe 'hi SpecialChar guifg='.s:fg4.' ctermfg=red'
exe 'hi SpecialComment guifg='.s:smoke.' gui=italic ctermfg=darkgray cterm=italic'
exe 'hi Statement guifg='.s:red.' gui=NONE ctermfg=red cterm=NONE'
exe 'hi StorageClass guifg='.s:candle.' ctermfg=yellow'
exe 'hi String guifg='.s:pentagram.' ctermfg=darkred'
exe 'hi Structure guifg='.s:red.' ctermfg=red'
exe 'hi Tag guifg='.s:candle.' ctermfg=yellow'
exe 'hi Todo guifg='.s:candle.' guibg='.s:bg0.' gui=bold ctermfg=yellow ctermbg=NONE cterm=bold'
exe 'hi Type guifg='.s:candle.' gui=NONE ctermfg=yellow cterm=NONE'
exe 'hi Typedef guifg='.s:candle.' ctermfg=yellow'

" Diff highlighting
exe 'hi DiffAdd guifg='.s:chalk.' guibg='.s:ritual.' gui=NONE ctermfg=white ctermbg=darkred cterm=NONE'
exe 'hi DiffChange guifg='.s:smoke.' guibg='.s:bg0.' gui=NONE ctermfg=darkgray ctermbg=black cterm=NONE'
exe 'hi DiffDelete guifg='.s:red.' guibg='.s:ritual.' gui=NONE ctermfg=red ctermbg=darkred cterm=NONE'
exe 'hi DiffText guifg='.s:chalk.' guibg='.s:blood.' gui=bold ctermfg=white ctermbg=red cterm=bold'

" GitGutter highlighting
exe 'hi GitGutterAdd guifg='.s:ritual.' guibg='.s:bg0.' ctermfg=darkred ctermbg=NONE'
exe 'hi GitGutterChange guifg='.s:candle.' guibg='.s:bg0.' ctermfg=yellow ctermbg=NONE'
exe 'hi GitGutterDelete guifg='.s:red.' guibg='.s:bg0.' ctermfg=red ctermbg=NONE'
exe 'hi GitGutterChangeDelete guifg='.s:crimson.' guibg='.s:bg0.' ctermfg=darkred ctermbg=NONE'

" NERDTree highlighting
exe 'hi NERDTreeDirSlash guifg='.s:red.' ctermfg=red'
exe 'hi NERDTreeExecFile guifg='.s:fg0.' ctermfg=red'

" Extra blood red highlights
exe 'hi SpecialKey guifg='.s:crimson.' guibg=NONE gui=NONE ctermfg=darkred ctermbg=NONE cterm=NONE'
exe 'hi Title guifg='.s:red.' guibg=NONE gui=bold ctermfg=red ctermbg=NONE cterm=bold'
exe 'hi Underlined guifg='.s:pentagram.' gui=underline ctermfg=darkred cterm=underline'
exe 'hi ErrorMsg guifg='.s:red.' guibg='.s:bg0.' gui=bold ctermfg=red ctermbg=NONE cterm=bold'
exe 'hi WarningMsg guifg='.s:candle.' guibg='.s:bg0.' gui=bold ctermfg=yellow ctermbg=NONE cterm=bold'
exe 'hi SignColumn guibg='.s:bg0.' guifg='.s:red.' ctermbg=NONE ctermfg=red'

" Terminal color definitions
let g:terminal_color_0 = s:bg0
let g:terminal_color_1 = s:red
let g:terminal_color_2 = s:ritual
let g:terminal_color_3 = s:candle
let g:terminal_color_4 = s:blood
let g:terminal_color_5 = s:crimson
let g:terminal_color_6 = s:pentagram
let g:terminal_color_7 = s:fg0
let g:terminal_color_8 = s:smoke
let g:terminal_color_9 = s:fg3
let g:terminal_color_10 = s:ritual
let g:terminal_color_11 = s:candle
let g:terminal_color_12 = s:blood
let g:terminal_color_13 = s:crimson
let g:terminal_color_14 = s:pentagram
let g:terminal_color_15 = s:bone

" Terminal support for vim
if has('terminal')
  let g:terminal_ansi_colors = [
        \ s:bg0, s:red, s:ritual, s:candle,
        \ s:blood, s:crimson, s:pentagram, s:fg0,
        \ s:smoke, s:fg3, s:ritual, s:candle,
        \ s:blood, s:crimson, s:pentagram, s:bone
        \ ]
endif

" Customize signs for occult symbols
sign define DiagnosticSignError text=☠ texthl=DiagnosticSignError linehl= numhl=
sign define DiagnosticSignWarn text=⚠ texthl=DiagnosticSignWarn linehl= numhl=
sign define DiagnosticSignInfo text=⚡ texthl=DiagnosticSignInfo linehl= numhl=
sign define DiagnosticSignHint text=⚒ texthl=DiagnosticSignHint linehl= numhl=

" Link standard groups to improve compatibility
hi! link Error ErrorMsg
hi! link Question WarningMsg
hi! link TabLine StatusLineNC
hi! link TabLineFill StatusLineNC
hi! link TabLineSel StatusLine
hi! link qfLineNr Type
hi! link qfError ErrorMsg
hi! link diffAdded DiffAdd
hi! link diffRemoved DiffDelete
hi! link diffChanged DiffChange
hi! link Conceal NonText
hi! link MoreMsg Title
hi! link DiagnosticError Error
hi! link DiagnosticWarn WarningMsg
hi! link DiagnosticInfo Special
hi! link DiagnosticHint Comment
hi! link DiagnosticSignError ErrorMsg
hi! link DiagnosticSignWarn WarningMsg
hi! link DiagnosticSignInfo Special
hi! link DiagnosticSignHint Comment 