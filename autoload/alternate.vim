" ============================================================================
" File:        alternate.vim
" Description: switch between alternate files
" Author:      Alexander Aksenov <facing-worlds@yandex.ru>
" License:     Vim license
" ============================================================================

if exists("loaded_alternate") && loaded_alternate
	finish
endif
let loaded_alternate = 1

" Init {{{
if exists('g:alternate_dict')
	let s:dict = g:alternate_dict
else
	" Directories {{{
	if exists('g:alternate_incdirs')
		let s:incdirs = g:alternate_incdirs
	else
		let s:incdirs = [
		              \   'reg:/src/include/',
		              \   'reg:/src/inc/',
		              \   'reg:/source/include/',
		              \   'gre:#.*\zs\<src\>.*#include**#',
		              \   'gre:#.*\zs\<src\>.*#inc**#',
		              \   'gre:#.*\zs\<source\>.*#include**#',
		              \   '',
		              \ ]
	endif

	if exists('g:alternate_srcdirs')
		let s:srcdirs = g:alternate_srcdirs
	else
		let s:srcdirs = [
		              \   'reg:/include/src/',
		              \   'reg:/inc/src/',
		              \   'reg:/include/source/',
		              \   'gre:#.*\zs\<include\>.*#src**#',
		              \   'gre:#.*\zs\<inc\>.*#src**#',
		              \   'gre:#.*\zs\<include\>.*#source**#',
		              \   '',
		              \ ]
	endif
	" }}}

	" Names {{{
	if exists('g:alternate_incnames')
		let s:incnames = g:alternate_incnames
	else
		let s:incnames = [ '' ]
	endif

	if exists('g:alternate_srcnames')
		let s:srcnames = g:alternate_srcnames
	else
		let s:srcnames = [ '' ]
	endif
	" }}}

	let s:dict = {}

	" C, C++, Objective-C {{{
	let s:dict['h']   = [ [ 'c', 'cpp', 'm', 'mm' ], s:srcdirs, s:srcnames ]
	let s:dict['hh']  = [ [ 'cc'                  ], s:srcdirs, s:srcnames ]
	let s:dict['hpp'] = [ [ 'cpp'                 ], s:srcdirs, s:srcnames ]
	let s:dict['hxx'] = [ [ 'cxx'                 ], s:srcdirs, s:srcnames ]
	let s:dict['H']   = [ [ 'C'                   ], s:srcdirs, s:srcnames ]

	let s:dict['c']   = [ [ 'h'                   ], s:incdirs, s:incnames ]
	let s:dict['cc']  = [ [ 'hh'                  ], s:incdirs, s:incnames ]
	let s:dict['cpp'] = [ [ 'hpp', 'h'            ], s:incdirs, s:incnames ]
	let s:dict['cxx'] = [ [ 'hxx'                 ], s:incdirs, s:incnames ]
	let s:dict['m']   = [ [ 'h'                   ], s:incdirs, s:incnames ]
	let s:dict['mm']  = [ [ 'h'                   ], s:incdirs, s:incnames ]
	let s:dict['C']   = [ [ 'H'                   ], s:incdirs, s:incnames ]
	" }}}

	" Extensions {{{
	if exists('g:alternate_incexts')
		for [s:key, s:value] in items(g:alternate_incexts)
			let s:dict[s:key] = [ s:value, s:incdirs, s:incnames ]
		endfor
		unlet s:key s:value
	endif

	if exists('g:alternate_srcexts')
		for [s:key, s:value] in items(g:alternate_srcexts)
			let s:dict[s:key] = [ s:value, s:srcdirs, s:srcnames ]
		endfor
		unlet s:key s:value
	endif
	" }}}

	" Extend dictionary {{{
	if exists('g:alternate_extenddict')
		call extend(s:dict, g:alternate_extenddict)
	endif
	" }}}

	unlet s:incdirs s:srcdirs s:incnames s:srcnames
endif
" }}}

" Helper functions {{{
function! s:Substitute(string, pattern)
	let sep = strpart(a:pattern, 0, 1)
	let patend = match(a:pattern, sep, 1)
	let pat = strpart(a:pattern, 1, patend - 1)
	let subend = match(a:pattern, sep, patend + 1)
	let sub = strpart(a:pattern, patend + 1, subend - patend - 1)
	let flags = strpart(a:pattern, strlen(a:pattern) - 2)
	if flags ==# sep
		let flags = ''
	endif
	return substitute(a:string, pat, sub, flags)
endfunction

function! s:HasBufferInTab(buffer, tab)
	let buffers = tabpagebuflist(a:tab)
	let index = 0
	let size = len(buffers)
	while index < size
		if a:buffer == buffers[index]
			return 1
		endif
		let index += 1
	endwhile
	return 0
endfunction

function! s:FindTabWithBuffer(buffer, curtab)
	let index = 0
	while index < a:curtab
		if s:HasBufferInTab(a:buffer, index)
			return index
		endif
		let index += 1
	endwhile
	let index = a:curtab + 1
	let size = tabpagenr('$')
	while index <= size
		if s:HasBufferInTab(a:buffer, index)
			return index
		endif
		let index += 1
	endwhile
	return 0
endfunction

function! s:FindtListItem(list, name, shift)
	let index = index(a:list, a:name)
	if index != -1
		let len = len(a:list)
		let index = (index + a:shift) % len
		if index < 0
			let index += len
		endif
	endif
	return index
endfunction

function! s:ExtsToSuffixes(exts)
	let suffixes = join(a:exts, ',.')
	if !empty(suffixes)
		let suffixes = '.' . suffixes
	endif
	return suffixes
endfunction
" }}}

" Core functions {{{
function! s:ExpandRoot(root, pattern)
	if empty(a:pattern)
		return a:root
	endif
	let prefix = strpart(a:pattern, 0, 4)
	if prefix ==# 'reg:'
		let pattern = strpart(a:pattern, 4)
		let root = s:Substitute(a:root, pattern)
		return root ==# a:root ? '' : root
	endif
	return ''
endfunction

function! s:ExpandDir(dir, pattern)
	let prefix = strpart(a:pattern, 0, 4)
	if prefix ==# 'reg:' || prefix ==# 'gre:'
		let pattern = strpart(a:pattern, 4)
		let dir = s:Substitute(a:dir, pattern)
		return dir ==# a:dir ? '' : dir
	elseif prefix ==# 'rel:'
		let dir = a:dir
		let dir .= exists('+shellslash') && !&shellslash ? '\' : '/'
		let dir .= strpart(a:pattern, 4)
		return dir
	elseif prefix ==# 'abs:'
		return strpart(a:pattern, 4)
	elseif empty(a:pattern)
		return a:dir
	endif
	return ''
endfunction

function! s:ExpandName(name, pattern)
	return s:ExpandRoot(a:name, a:pattern)
endfunction

function! s:FindExistingFile(root, exts)
	let dir = fnamemodify(a:root, ':h')
	if !isdirectory(dir)
		return
	endif
	let root = a:root . '.'
	for ext in a:exts
		let file = root . ext
		if filereadable(file)
			return fnamemodify(file, ':p')
		endif
	endfor
	return ''
endfunction

function! s:FindGlob(dir, name, names, exts)
	try
		let save_sua = &suffixesadd
		let &suffixesadd = ''
		for name in a:names
			let name = s:ExpandName(a:name, name)
			if empty(name)
				continue
			endif
			for ext in a:exts
				let file = findfile(name . '.' . ext, a:dir)
				if !empty(file)
					return fnamemodify(file, ':p')
				endif
			endfor
		endfor
	finally
		let &suffixesadd = save_sua
	endtry
	return ''
endfunction

function! s:FindExistingFile1(root, roots, exts)
	for root in a:roots
		let root = s:ExpandRoot(a:root, root)
		if empty(root)
			continue
		endif
		let file = s:FindExistingFile(root, a:exts)
		if !empty(file)
			return file
		endif
	endfor
	return ''
endfunction

function! s:FindExistingFile2(dir, dirs, name, names, exts)
	for dir in a:dirs
		if dir[0] ==# 'g'
			let dir = s:ExpandDir(a:dir, dir)
			if empty(dir)
				continue
			endif
			let file = s:FindGlob(dir, a:name, a:names, a:exts)
			if !empty(file)
				return file
			endif
		else
			let dir = s:ExpandDir(a:dir, dir)
			if !isdirectory(dir)
				continue
			endif
			let dir = fnamemodify(dir, ':p')
			for name in a:names
				let name = s:ExpandName(a:name, name)
				if empty(name)
					continue
				endif
				let root = dir . name
				let file = s:FindExistingFile(root, a:exts)
				if !empty(file)
					return file
				endif
			endfor
		endif
	endfor
	return ''
endfunction

function! s:FindAlternateFile(filename, dict)
	let altfile = ''
	let ext = fnamemodify(a:filename, ':e')
	if has_key(a:dict, ext)
		let patterns = a:dict[ext]
		let len = len(patterns)
		if len == 2
			let exts = patterns[0]
			let roots = patterns[1]
			let root = fnamemodify(a:filename, ':p:r')
			let altfile = s:FindExistingFile1(root, roots, exts)
		elseif len == 3
			let exts = patterns[0]
			let dirs = patterns[1]
			let names = patterns[2]
			let dir = fnamemodify(a:filename, ':p:h')
			let name = fnamemodify(a:filename, ':t:r')
			let altfile = s:FindExistingFile2(dir, dirs, name, names, exts)
		endif
	endif
	return altfile
endfunction

function! s:FindAllFiles(root, exts, mode, filehash, namehash, files)
	let dir = fnamemodify(a:root, ':h')
	if !isdirectory(dir)
		return
	endif
	let root = a:root . '.'
	let name = fnamemodify(root, ':t')
	for ext in a:exts
		let file = root . ext
		if !has_key(a:filehash, file)
			let filename = name . ext
			if a:mode == 2 ||
			 \ (a:mode == 1 && !has_key(a:namehash, filename)) ||
			 \ filereadable(file)
				let a:filehash[file] = 1
				let a:namehash[filename] = 1
				call add(a:files, file)
			endif
		endif
	endfor
endfunction

function! s:FindAllGlob(dir, name, names, exts,
                      \ mode, filehash, namehash, globhash, files)
	try
		let save_sua = &suffixesadd
		let &suffixesadd = ''
		for name in a:names
			let name = s:ExpandName(a:name, name)
			if empty(name)
				continue
			endif
			for ext in a:exts
				let filename = name . '.' . ext

				if !has_key(a:globhash, a:dir)
					let a:globhash[a:dir] = [ filename  ]
				elseif index(a:globhash[a:dir], filename) == -1
					call add(a:globhash[a:dir], filename)
				else
					continue
				endif

				let files = findfile(filename, a:dir, -1)
				for file in files
					let file = fnamemodify(file, ':p')
					if !has_key(a:filehash, file)
						let filename = fnamemodify(file, ':t')
						let a:filehash[file] = 1
						let a:namehash[filename] = 1
						call add(a:files, file)
					endif
				endfor
			endfor
		endfor
	finally
		let &suffixesadd = save_sua
	endtry
	return ''
endfunction

function! s:FindAllFiles1(root, roots, exts, mode, filehash, namehash)
	let files = []
	for root in a:roots
		let root = s:ExpandRoot(a:root, root)
		if empty(root)
			continue
		endif
		call s:FindAllFiles(root, a:exts, a:mode,
		                  \ a:filehash, a:namehash, files)
	endfor
	return files
endfunction

function! s:FindAllFiles2(dir, dirs, name, names, exts, mode,
                        \ filehash, namehash, globhash)
	let files = []
	for dir in a:dirs
		if dir[0] ==# 'g'
			let dir = s:ExpandDir(a:dir, dir)
			if empty(dir)
				continue
			endif
			call s:FindAllGlob(dir, a:name, a:names, a:exts,
			                 \ a:mode, a:filehash, a:namehash, a:globhash, files)
		else
			let dir = s:ExpandDir(a:dir, dir)
			if !isdirectory(dir)
				continue
			endif
			let dir = fnamemodify(dir, ':p')
			for name in a:names
				let name = s:ExpandName(a:name, name)
				if empty(name)
					continue
				endif
				let root = dir . name
				call s:FindAllFiles(root, a:exts, a:mode,
				                  \ a:filehash, a:namehash, files)
			endfor
		endif
	endfor
	return files
endfunction

function! s:FindAllAlternateFiles(filename, dict, mode)
	let altlist = []
	let forlist = [ a:filename ]
	let hash = {}
	let filehash = {}
	let namehash = {}
	let globhash = {}
	let mode = 0
	while 1
		let list = []
		for file in forlist
			if has_key(hash, file)
				continue
			endif
			let hash[file] = 1
			let ext = fnamemodify(file, ':e')
			if has_key(a:dict, ext)
				let patterns = a:dict[ext]
				let len = len(patterns)
				if len == 2
					let exts = patterns[0]
					let roots = patterns[1]
					let root = fnamemodify(a:filename, ':p:r')
					let list += s:FindAllFiles1(root, roots, exts,
					                          \ mode, filehash, namehash)
				elseif len == 3
					let exts = patterns[0]
					let dirs = patterns[1]
					let names = patterns[2]
					let dir = fnamemodify(file, ':p:h')
					let name = fnamemodify(file, ':t:r')
					let list += s:FindAllFiles2(dir, dirs, name, names, exts,
					                          \ mode, filehash, namehash, globhash)
				endif
			endif
		endfor
		if empty(list)
			if mode == 0 && a:mode != mode
				let mode = a:mode
				let hash = {}
				if !empty(altlist)
					let forlist = altlist
				endif
				continue
			endif
			break
		endif
		let altlist += list
		let forlist = list
	endwhile
	let altlist = sort(altlist)
	return altlist
endfunction
" }}}

" Interface functions {{{
function! s:SwitchFile(buffer, file, cmd)
	let file = fnamemodify(a:file, ':~:.')
	if a:cmd[0] ==# 'g'
		if a:buffer == -1
			execute 'edit ' . escape(file, ' ')
		else
			let curtab = tabpagenr()
			if s:HasBufferInTab(a:buffer, curtab)
				execute bufwinnr(a:buffer) . 'wincmd w'
			else
				let tab = s:FindTabWithBuffer(a:buffer, curtab)
				if tab
					execute 'tabnext ' . tab
				else
					execute 'buffer ' . file
				endif
			endif
		endif
	elseif a:cmd[0] ==# 'e'
		if a:buffer == -1
			execute 'edit ' . escape(file, ' ')
		else
			execute 'buffer ' . file
		endif
	elseif a:cmd[0] ==# 's' || a:cmd[0] ==# 'v'
		if a:buffer == -1
			execute (a:cmd[0] ==# 'v' ? 'vertical ' : '' ) . 'split ' .
			       \ escape(file, ' ')
		elseif a:cmd[1] != '!' && s:HasBufferInTab(a:buffer, tabpagenr())
			execute bufwinnr(a:buffer) . 'wincmd w'
		else
			execute (a:cmd[0] ==# 'v' ? 'vertical ' : '' ) . 'sbuffer ' . a:buffer
		endif
	elseif a:cmd[0] ==# 't'
		if a:buffer == -1
			execute 'tabedit ' . escape(file, ' ')
		elseif a:cmd[1] == '!'
			execute 'tabedit ' . escape(file, ' ')
		else
			let curtab = tabpagenr()
			let tab = s:FindTabWithBuffer(a:buffer, curtab)
			if tab
				execute 'tabnext ' . tab
				execute bufwinnr(a:buffer) . 'wincmd w'
			else
				execute 'tabedit ' . escape(file, ' ')
			endif
		endif
	endif
endfunction

function! s:KeepAlternateFile(altfile, file)
	let altbuf = bufnr(a:altfile)
	call setbufvar(altbuf, 'alternate_file', a:file)
endfunction

function! s:KeepAlternateList(altfile, altlist)
	let altbuf = bufnr(a:altfile)
	call setbufvar(altbuf, 'alternate_list', a:altlist)
endfunction

function! s:GetAlternateDict(buffer)
	let dict = getbufvar(a:buffer, 'alternate_dict')
	return empty(dict) ? s:dict : dict
endfunction

function! s:GetAlternateFile(file)
	let buffer = bufnr(a:file)
	let altfile = getbufvar(buffer, 'alternate_file')
	if empty(altfile)
		let dict = s:GetAlternateDict(buffer)
		let altfile = s:FindAlternateFile(a:file, dict)
	endif
	return altfile
endfunction

function! s:GetAlternateList(file)
	let buffer = bufnr(a:file)
	let altlist = getbufvar(buffer, 'alternate_list')
	if empty(altlist)
		let dict = s:GetAlternateDict(buffer)
		unlet altlist
		let altlist = s:FindAllAlternateFiles(a:file, dict, 0)
		for file in altlist
			call s:KeepAlternateList(file, altlist)
		endfor
	endif
	return altlist
endfunction

function! s:AskAlternateFile(file, mode)
	if a:mode == 0
		let altlist = s:GetAlternateList(a:file)
	else
		let buffer = bufnr(a:file)
		let dict = s:GetAlternateDict(buffer)
		let altlist = s:FindAllAlternateFiles(a:file, dict, a:mode)
	endif
	if empty(altlist)
		echo 'No alternate files'
		return ''
	endif
	let prompt = [ 'Select file:' ]
	let index = 0
	let current = index(altlist, a:file)
	let size = len(altlist)
	while index < size
		let file = altlist[index]
		if index == current
			let line = '[' . (index + 1) . '] '
		else
			let line = (filereadable(file) ? '+' : ' ') . (index + 1) . ': '
		endif
		let line .= fnamemodify(file, ':~:.')
		call add(prompt, line)
		let index += 1
	endwhile
	let index = inputlist(prompt) - 1
	if index >= 0 && index < size
		return altlist[index]
	endif
	return ''
endfunction
" }}}

function! alternate#switch(file, count, action)
	let file = expand(a:file)
	let file = fnamemodify(file, ':p')

	if a:count
		let altlist = s:GetAlternateList(file)
		if empty(altlist)
			echo 'No alternate file'
			return
		endif
		if a:count < 1
			let altfile = altlist[0]
		elseif a:count > len(altlist)
			let altfile = altlist[-1]
		else
			let altfile = altlist[a:count - 1]
		endif
		if file ==# altfile
			return
		endif
	else
		let altfile = s:GetAlternateFile(file)
		if empty(altfile) || file ==# altfile
			echo 'No alternate file'
			return
		endif
	endif

	let altbuf = bufnr(altfile)
	call s:SwitchFile(altbuf, altfile, a:action)
	call s:KeepAlternateFile(altfile, file)
	call s:KeepAlternateFile(file, altfile)
	if altbuf == -1 && exists('l:altlist')
		call s:KeepAlternateList(altfile, altlist)
	endif
endfunction

function! alternate#next(file, count, action)
	let file = expand(a:file)
	let file = fnamemodify(file, ':p')

	let altlist = s:GetAlternateList(file)
	let index = s:FindtListItem(altlist, file, a:count)
	if index < 0
		echo 'No alternate file'
		return
	endif
	let altfile = altlist[index]
	if file ==# altfile
		return
	endif

	let altbuf = bufnr(altfile)
	call s:SwitchFile(altbuf, altfile, a:action)
	call s:KeepAlternateFile(altfile, file)
	call s:KeepAlternateFile(file, altfile)
	if altbuf == -1 && exists('l:altlist')
		call s:KeepAlternateList(altfile, altlist)
	endif
endfunction

function! alternate#list(file, action, mode)
	let file = expand(a:file)
	let file = fnamemodify(file, ':p')

	let altfile = s:AskAlternateFile(file, a:mode)
	if empty(altfile)
		return
	endif

	let altbuf = bufnr(altfile)
	call s:SwitchFile(altbuf, altfile, a:action)
	call s:KeepAlternateFile(altfile, file)
	call s:KeepAlternateFile(file, altfile)
	if altbuf == -1 && exists('l:altlist')
		call s:KeepAlternateList(altfile, altlist)
	endif
endfunction

" vim:ts=4 sw=4 noet fdm=marker:
