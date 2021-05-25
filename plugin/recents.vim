if exists('g:loaded_recents')
	finish
endif

let s:save_cpo = &cpo
set cpo&vim

command! Recents lua require'recents'.recents()
command! EditRecents lua require'recents'.edit_recents()
au DirChanged * lua require'recents'.dir_changed()
au VimEnter * lua require'recents'.load_from_file()

let &cpo = s:save_cpo
unlet s:save_cpo

let g:loaded_recents = 1
