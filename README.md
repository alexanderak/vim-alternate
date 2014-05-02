This Vim plugin allows you to quick switch between alternate files same as a.vim or fswitch.


Put this to your .vimrc.


Go to file.  
`command! -nargs=? -complete=file -count=0 A  call alternate#switch('%', <count>, 'g')`

Edit file.  
`command! -nargs=? -complete=file -count=0 AE call alternate#switch('%', <count>, 'e')`

Split, vertical split, new tab.  
`command! -nargs=? -complete=file -count=0 -bang AS call alternate#switch('%', <count>, 's<bang>')`  
`command! -nargs=? -complete=file -count=0 -bang AV call alternate#switch('%', <count>, 'v<bang>')`  
`command! -nargs=? -complete=file -count=0 -bang AT call alternate#switch('%', <count>, 't<bang>')`

Cycle throw files.   
`command! -nargs=? -complete=file -count=1 AN call alternate#next('%', <count>, 'e')`  
`command! -nargs=? -complete=file -count=1 AP call alternate#next('%', <count>, 'e')`

List files.  
`command! -nargs=? -complete=file       AA call alternate#list('%', 'e', 0)`  
`command! -nargs=? -complete=file -bang AC call alternate#list('%', 'e', empty('<bang>') ? 1 : 2)`


Usefull mappings.  
`nnoremap <silent> ga :<C-U>call alternate#switch('%', v:count, 'g')<CR>`  
`nnoremap <silent> [a :<C-U>call alternate#next('%', -v:count1, 'e')<CR>`  
`nnoremap <silent> ]a :<C-U>call alternate#next('%', v:count1, 'e')<CR>`


Please see code for details.
