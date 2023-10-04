set nocompatible
set laststatus=3

# vim-pencil
augroup pencil
  autocmd!
  autocmd FileType markdown call pencil#init({'wrap': 'hard', 'autoformat': 1})
  autocmd FileType text     call pencil#init({'wrap': 'hard', 'autoformat': 0})
augroup END

" Disable bookmark keybindings
let g:bookmark_no_default_key_mappings = 1
