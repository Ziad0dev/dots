"***********************************************************************************
"    ___          _                       
"   / __\  __ _  | |_   __ _  _ __      
"  / /    / _` | | __| / _` || '_ \     
" / /___ | (_| | | |_ | (_| || | | |    
" \____/  \__,_|  \__| \__,_||_| |_|    
"                                        
"***********************************************************************************

" Satan theme cursor settings
set guicursor=n-v-c:block-Cursor/lCursor-blinkwait666-blinkoff150-blinkon175
set guicursor+=i-ci:ver25-Cursor/lCursor-blinkwait175-blinkoff150-blinkon175
set guicursor+=r-cr:hor20-Cursor/lCursor-blinkwait175-blinkoff150-blinkon175

" Set cursor colors for different modes - intense blood red
highlight Cursor guifg=#000000 guibg=#FF0000 gui=bold
highlight iCursor guifg=#000000 guibg=#BF0000 gui=bold

" Blood drip effect for cursor blink (special effect for insert mode)
autocmd InsertEnter * highlight Cursor guibg=#BF0000
autocmd InsertLeave * highlight Cursor guibg=#FF0000

" Custom cursor shape in terminal mode
if exists('$TMUX')
  let &t_SI = "\<Esc>Ptmux;\<Esc>\<Esc>]50;CursorShape=1\x7\<Esc>\\"
  let &t_SR = "\<Esc>Ptmux;\<Esc>\<Esc>]50;CursorShape=2\x7\<Esc>\\"
  let &t_EI = "\<Esc>Ptmux;\<Esc>\<Esc>]50;CursorShape=0\x7\<Esc>\\"
else
  let &t_SI = "\<Esc>]50;CursorShape=1\x7"
  let &t_SR = "\<Esc>]50;CursorShape=2\x7"
  let &t_EI = "\<Esc>]50;CursorShape=0\x7"
endif 
