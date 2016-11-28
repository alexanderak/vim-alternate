" ============================================================================
" File:        autoload/alternate.vim
" Description: switch between alternate files
" Author:      Alexander Aksenov <facing-worlds@yandex.ru>
" License:     Vim license
" ============================================================================

let s:groups = [
	\   [ '{include|inc}/**/{}.h', '{src|source}/**/{}.{cpp|mm}' ],
	\   [ '{include|inc}/**/{}.h', '{src|source}/**/{}.{c|m}' ],
	\   [ '{include|inc}/**/{}.hpp', '{src|source}/**/{}.cpp' ],
	\   [ '{include|inc}/**/{}.hxx', '{src|source}/**/{}.cxx' ],
	\   [ '{include|inc}/**/{}.hh', '{src|source}/**/{}.cc' ],
	\   [ '{include|inc}/**/{}.H', '{src|source}/**/{}.C' ],
	\   [ '{}.h', '{}.{cpp|mm}' ],
	\   [ '{}.h', '{}.{c|m}' ],
	\   [ '{}.hpp', '{}.cpp' ],
	\   [ '{}.hxx', '{}.cxx' ],
	\   [ '{}.hh', '{}.cc' ],
	\   [ '{}.H', '{}.C' ],
	\   [ 'doc/{}.txt', 'plugin/{}.vim', 'autoload/{}.vim' ],
	\ ]

" Match {{{
if exists('*uniq')
	function! s:uniq_sort(list)
		return uniq(sort(a:list))
	endfunction
else
	function! s:uniq_sort(list)
		let dict = {}
		for item in a:list
			let dict[item] = 1
		endfor
		return sort(keys(dict))
	endfunction
endif

if exists('*systemlist')
	function! s:systemlist(expr)
		return systemlist(a:expr)
	endfunction
else
	function! s:systemlist(expr)
		return split(system(a:expr), '\n')
	endfunction
endif

function! s:backslash()
	return exists('+shellslash') && !&shellslash
endfunction

function! s:star2re(str)
	if a:str[0] ==# '/'
		if a:str[len(a:str) - 1] ==# '/'
			return a:str =~# '\*\*\+' ? '\%(/\|/\.\+/\)' : '\%(/\|/\[^/]\+/\)'
		endif
		return a:str =~# '\*\*\+' ? '\%(/\.\*\)' : '\%(/\[^/]\*\)'
	elseif a:str[len(a:str) - 1] ==# '/'
		return a:str =~# '\*\*\+' ? '\%(\.\*/\)' : '\%(\[^/]\*/\)'
	else
		return a:str =~# '\*\*\+' ? '\%(\.\*\)' : '\%(\[^/]\*\)'
	endif
endfunction

function! s:glob2re(str)
	if a:str[0] ==# '{'
		return '\%(' . substitute(escape(a:str[1 : -2], '\'), '|', '\\|', 'g') . '\)'
	else
		return s:star2re(a:str)
	endif
endfunction

function! s:match_template(num, template, filename, result)
	let re = substitute(a:template, '\%(/\?\*\+/\?\)\|\%({[^{}]\+}\)', '\=s:glob2re(submatch(0))', 'g')
	if s:backslash()
		let re = substitute(re, '/', '\\\\', 'g')
		let re = substitute(re, '{}', '\\(\\zs\\[^\\\\]\\+\\ze\\)', '')
	else
		let re = substitute(re, '{}', '\\(\\zs\\[^/]\\+\\ze\\)', '')
	endif
	let re = '\V\C' . substitute(re, '{}', '\1', 'g') . '\$'
	let n = match(a:filename, re)
	if n >= 0
		let m = matchend(a:filename, re)
		if a:result[0] < 0 || m - n < len(a:result[1])
			let a:result[0] = a:num
			let a:result[1] = strpart(a:filename, n, m - n)
		endif
	endif
	return a:template
endfunction
" }}}

" Expand {{{
function! s:split_template(template, name)
	let result = []
	let template = substitute(a:template, '{}', a:name, 'g')
	let pat = '\%(/\?\*\+/\?\)\|\%({[^{}]\+}\)'
	while template isnot ''
		let pos = match(template, pat)
		if pos < 0
			call add(result, template)
			break
		elseif pos > 0
			call add(result, strpart(template, 0, pos))
			let template = strpart(template, pos)
		endif
		let str = matchstr(template, pat)
		let len = len(str)
		if str[0] ==# '{'
			call add(result, split(strpart(str, 1, len - 2), '|', 1))
		else
			call add(result, str)
		endif
		let template = strpart(template, len)
	endwhile
	return result
endfunction

function! s:walk_matches_component(components, num, path, glob, parts, result, component)
	let comp = '\V\C' . escape(a:component, '\')
	if s:backslash()
		let comp = substitute(comp, '/', '\\\\', 'g')
	endif
	let counter = 1
	let pos = match(a:path, comp, 0, counter)
	while pos >= 0
		if !empty(a:glob) && strpart(a:path, 0, pos) !~# '\V\C\^' . a:glob . '\$'
			break
		endif
		if a:num == 0 || !empty(a:glob)
			call add(a:parts, strpart(a:path, 0, pos))
		endif
		let n = matchend(a:path, comp, pos)
		call s:walk_matches(a:components, a:num + 1, strpart(a:path, n), '', a:parts, a:result)
		if a:num == 0 || !empty(a:glob)
			unlet a:parts[-1]
		endif
		let counter += 1
		let pos = match(a:path, comp, 0, counter)
	endwhile
endfunction

function! s:walk_matches(components, num, path, glob, parts, result)
	if a:num >= len(a:components)
		if empty(a:path)
			call add(a:result, copy(a:parts))
		endif
	elseif type(a:components[a:num]) == 3
		for comp in a:components[a:num]
			if empty(comp)
				call s:walk_matches(a:components, a:num + 1, a:path, a:glob, a:parts, a:result)
			else
				call s:walk_matches_component(a:components, a:num, a:path, a:glob, a:parts, a:result, comp)
			endif
		endfor
	elseif a:components[a:num] =~# '/\?\*\+/\?'
		let glob = s:star2re(a:components[a:num])
		if s:backslash()
			let glob = substitute(glob, '/', '\\\\', 'g')
		endif
		call s:walk_matches(a:components, a:num + 1, a:path, a:glob . glob, a:parts, a:result)
	else
		call s:walk_matches_component(a:components, a:num, a:path, a:glob, a:parts, a:result, a:components[a:num])
	endif
endfunction

function! s:expand_wildcards(list, filename, parts)
	let p = 1
	let i = 0
	let N = len(a:list)
	let backslash = s:backslash()
	while i < N
		if type(a:list[i]) != 3
			if a:list[i] =~# '\*' && p < len(a:parts)
				let a:list[i] = a:parts[p]
				let p += 1
			elseif backslash
				let a:list[i] = substitute(a:list[i], '/', '\\', 'g')
			endif
		elseif backslash
			call map(a:list[i], "substitute(v:val, '/', '\\', 'g')")
		endif
		let i += 1
	endwhile
	if !empty(a:list) && !empty(a:parts)
		if type(a:list[0]) != 3
			let a:list[0] = a:parts[0] . a:list[0]
		else
			call insert(a:list, a:parts[0])
		endif
	endif
endfunction

function! s:walk_components(components, visitor, num, path)
	if a:num >= len(a:components)
		return a:visitor.visit(a:path)
	endif
	if type(a:components[a:num]) == 3
		for component in a:components[a:num]
			let result = s:walk_components(a:components, a:visitor, a:num + 1, a:path . component)
			if result
				return result
			endif
		endfor
		return 0
	endif
	return s:walk_components(a:components, a:visitor, a:num + 1, a:path . a:components[a:num])
endfunction
" }}}

" Visitors {{{
function! s:base_visitor(path, mode)
	let visitor = {}
	let visitor.path = a:path
	let visitor.filename = fnamemodify(a:path, ':t:r')
	let visitor.mode = a:mode
	let visitor.result = []
	let visitor.found = 0
	let visitor.existing = 0

	function visitor.begin(multiparts) dict
		let self.found = 0
	endfunction

	function visitor.end() dict
		if self.mode == 0
			if len(self.result) > 1
				if fnamemodify(self.result[-1], ':t:r') ==# self.filename
					unlet self.result[ : -2]
				else
					unlet self.result[1 : ]
				endif
			endif
			let self.existing = self.found
			return self.found
		elseif self.mode == 1
			let self.existing = self.found
			return self.found
		else
			return self.mode == 2 ? self.existing : 0
		endif
	endfunction

	return visitor
endfunction

function! s:common_visitor(path, mode)
	let visitor = s:base_visitor(a:path, a:mode)

	if visitor.mode == 0 " first existing file
		function visitor.visit(expr) dict
			if a:expr !=# self.path && filereadable(a:expr)
				call add(self.result, a:expr)
				let self.found += 1
				return fnamemodify(a:expr, ':t:r') ==# self.filename
			endif
			return 0
		endfunction
	elseif visitor.mode == 1 " all existing files
		function visitor.visit(expr) dict
			if filereadable(a:expr)
				call add(self.result, a:expr)
				if a:expr !=# self.path
					let self.found += 1
				endif
			endif
			return 0
		endfunction
	else " existing + possible files
		function visitor.visit(expr) dict
			if isdirectory(fnamemodify(a:expr, ':h'))
				call add(self.result, a:expr)
				if a:expr !=# self.path
					let self.found += 1
					if filereadable(a:expr)
						let self.existing += 1
					endif
				endif
			endif
			return 0
		endfunction
	endif

	return visitor
endfunction

function! s:glob_visitor(path, mode)
	let visitor = s:base_visitor(a:path, a:mode ? 1 : 0)

	let visitor.glob_cache = {}
	function visitor.glob(expr) dict
		if !has_key(self.glob_cache, a:expr)
			let self.glob_cache[a:expr] = self.glob_func(a:expr)
		endif
		return self.glob_cache[a:expr]
	endfunction

	if s:backslash()
		function visitor.glob_func(expr) dict
			let expr = substitute(a:expr, '\\\*\*\\', '/**/', 'g')
			return glob(expr, 0, 1)
		endfunction
	else
		function visitor.glob_func(expr) dict
			return glob(a:expr, 0, 1)
		endfunction
	endif

	function! visitor.begin(multiparts) dict
		for parts in a:multiparts
			if len(parts) > 1
				unlet parts[1 : ]
			endif
		endfor
		let self.found = 0
	endfunction

	if visitor.mode == 0 " first existing file
		function visitor.visit(expr) dict
			for file in self.glob(a:expr)
				if file !=# self.path
					call add(self.result, file)
					let self.found += 1
					return fnamemodify(a:expr, ':t:r') ==# self.filename
				endif
			endfor
			return 0
		endfunction
	else " all existing files
		function visitor.visit(expr) dict
			let list = self.glob(a:expr)
			for file in list
				if file !=# self.path
					let self.found += 1
					break
				endif
			endfor
			call extend(self.result, list)
			return 0
		endfunction
	endif
	return visitor
endfunction

function! s:fugitive_glob2re(str)
	return a:str ==# '*' ? '\(\[^/]\*\)' : '\(\.\*\)'
endfunction

function! s:fugitive_visitor(path, mode, buffer)
	let visitor = s:glob_visitor(a:path, a:mode)

	let visitor.backslash = s:backslash()
	let visitor.start = len(a:path) - len(fugitive#buffer(a:buffer).path())
	let visitor.prefix = strpart(a:path, 0, visitor.start)

	let commit = fugitive#buffer(a:buffer).commit()
	let command = fugitive#buffer(a:buffer).repo().git_command() . ' ls-tree --name-only --full-tree -r ' . commit
	let visitor.filelist = s:systemlist(command)

	function! visitor.glob_func(expr) dict
		let result = []
		let expr = strpart(a:expr, self.start)
		if self.backslash
			let expr = substitute(expr, '\\', '/', 'g')
		endif
		let expr = substitute(expr, '*\+', '\=s:fugitive_glob2re(submatch(0))', 'g')
		let expr = '\V\C' . expr . '\$'
		let list = filter(copy(self.filelist), 'v:val =~# expr')
		if self.backslash
			call map(list, "self.prefix . substitute(v:val, '/', '\\', 'g')")
		else
			call map(list, 'self.prefix . v:val')
		endif
		call extend(result, list)
		return result
	endfunction

	return visitor
endfunction
" }}}

" Find {{{
function! s:find_algo(chain, path, visitor)
	let filename = fnamemodify(a:path, ':t:r')
	for groups in a:chain
		for templates in groups
			let match_result = [ -1, '' ]
			call map(templates, 's:match_template(v:key, v:val, a:path, match_result)')
			if match_result[0] >= 0
				let [ num, name ] = match_result
				let multiparts = []
				let components = s:split_template(templates[num], name)
				call s:walk_matches(components, 0, a:path, '', [], multiparts)
				call a:visitor.begin(multiparts)
				let range = range(len(templates))
				unlet range[num]
				call add(range, num)
				for i in range
					let components = s:split_template(templates[i], name)
					for parts in multiparts
						let comps = copy(components)
						call s:expand_wildcards(comps, filename, parts)
						if s:walk_components(comps, a:visitor, 0, '')
							if a:visitor.end()
								return templates
							endif
							break
						endif
					endfor
				endfor
				if a:visitor.end()
					return templates
				endif
			endif
		endfor
	endfor
	return []
endfunction

function! s:find_files(chain, path, mode)
	let fugitive = 'fugitive:'
	if strpart(a:path, 0, len(fugitive)) ==# fugitive
		let buffer = bufnr(a:path)
		if buffer < 0
			let result = []
		elseif s:backslash() && strpart(a:path, len(fugitive), len('//')) ==# '//'
			let path = substitute(a:path, '/', '\\', 'g')
			let visitor = s:fugitive_visitor(path, a:mode, buffer)
			call s:find_algo(a:chain, path, visitor)
			let result = map(visitor.result, "substitute(v:val, '\\', '/', 'g')")
		else
			let visitor = s:fugitive_visitor(a:path, a:mode, buffer)
			call s:find_algo(a:chain, a:path, visitor)
			let result = visitor.result
		endif
	else
		let visitor = s:common_visitor(a:path, a:mode)
		call s:find_algo(a:chain, a:path, visitor)
		if visitor.existing
			let result = visitor.result
		else
			let glob_visitor = s:glob_visitor(a:path, a:mode)
			let templates = s:find_algo(a:chain, a:path, glob_visitor)
			if glob_visitor.existing
				if a:mode > 1
					call s:uniq_sort(glob_visitor.result)
					let result = []
					let chain = a:mode == 2 ? [ [ templates ] ] : a:chain
					for file in glob_visitor.result
						let visitor = s:common_visitor(file, a:mode)
						call s:find_algo(chain, file, visitor)
						call extend(result, visitor.result)
					endfor
				else
					let result = glob_visitor.result
				endif
			else
				let result = visitor.result
			endif
		endif
	endif
	call s:uniq_sort(result)
	return result
endfunction
" }}}

" Interface {{{
function! s:find_buffer_tab(buffer, curtab)
	let i = 1
	while i < a:curtab
		if index(tabpagebuflist(i), a:buffer) >= 0
			return i
		endif
		let i += 1
	endwhile
	let i = a:curtab + 1
	let N = tabpagenr('$')
	while i <= N
		if index(tabpagebuflist(i), a:buffer) >= 0
			return i
		endif
		let i += 1
	endwhile
	return 0
endfunction

function! s:switch_file(buffer, file, cmd)

	" Use switchbuf option
	if empty(a:cmd)
		if &switchbuf =~# 'newtab'
			let cmd = 't'
		elseif &switchbuf =~# 'split'
			let cmd= 's'
		elseif &switchbuf =~# 'usetab'
			let cmd= 'g!e'
		elseif &switchbuf =~# 'useopen'
			let cmd= 'ge'
		else
			let cmd = 'e'
		endif
		call s:switch_file(a:buffer, a:file, cmd)
		return
	endif
	
	" Go to opened buffer
	if a:buffer != -1 && a:cmd =~ 'g'
		if a:cmd =~# 'g'
			let curtab = tabpagenr()
			if index(tabpagebuflist(curtab), a:buffer) >= 0
				execute bufwinnr(a:buffer) . 'wincmd w'
				return
			endif
			if a:cmd =~# 'g!'
				let tab = s:find_buffer_tab(a:buffer, curtab)
				if tab
					execute 'tabnext' tab
					execute bufwinnr(a:buffer) . 'wincmd w'
					return
				endif
			endif
		else
			let curtab = tabpagenr()
			let tab = s:find_buffer_tab(a:buffer, curtab)
			if tab
				execute 'tabnext' tab
				execute bufwinnr(a:buffer) . 'wincmd w'
				return
			endif
			if a:cmd =~# 'G!'
				if index(tabpagebuflist(curtab), a:buffer) >= 0
					execute bufwinnr(a:buffer) . 'wincmd w'
					return
				endif
			endif
		endif
	endif

	let file = fnamemodify(a:file, ':~:.')

	" Use current window
	if a:cmd =~ 'e'
		let bang = a:cmd =~ 'e!' ? '!' : ''
		if a:buffer == -1
			execute 'edit' . bang escape(file, ' ')
		else
			execute 'buffer' . bang a:buffer
		endif

	" Split window
	elseif a:cmd =~ 's'
		let where = a:cmd =~ 's!' ? (&splitbelow ? 'leftabove ' : 'rightbelow ') : ''
		if a:buffer == -1
			execute where . 'split' escape(file, ' ')
		else
			execute where . 'sbuffer' a:buffer
		endif

	" Verical split
	elseif a:cmd =~ 'v'
		let where = a:cmd =~ 'v!' ? (&splitright ? 'leftabove ' : 'rightbelow ') : ''
		if a:buffer == -1
			execute where . 'vsplit' escape(file, ' ')
		else
			execute where . 'vertical sbuffer' a:buffer
		endif

	" Tab
	elseif a:cmd =~ 't'
		execute 'tabedit' escape(file, ' ')

	endif
endfunction

function! s:keep_alt(altfile, stuff)
	let altbuf = bufnr(a:altfile)
	call setbufvar(altbuf, type(a:stuff) == 3 ? 'alternate_list' : 'alternate_file', a:stuff)
endfunction

function! s:groups_chain(buffer)
	let list = getbufvar(a:buffer, 'alternate_templates')
	if !empty(list)
		return [ list ]
	endif
	let chain = []
	let list = getbufvar(a:buffer, 'alternate_groups')
	if !empty(list)
		call add(chain, list)
		if empty(list[-1])
			return chain
		endif
	endif
	if !empty(get(g:, 'alternate_groups', []))
		call add(chain, g:alternate_groups)
		if empty(g:alternate_groups[-1])
			return chain
		endif
	endif
	return add(chain, s:groups)
endfunction

function! s:alternate_file(file)
	let buffer = bufnr(a:file)
	let altfile = getbufvar(buffer, 'alternate_file')
	if altfile is ''
		let list = s:find_files(s:groups_chain(buffer), a:file, 0)
		let altfile = empty(list) ? '' : list[0]
	endif
	return altfile
endfunction

function! s:alternate_list(file)
	let buffer = bufnr(a:file)
	let altlist = getbufvar(buffer, 'alternate_list')
	if empty(altlist)
		unlet altlist
		let altlist = s:find_files(s:groups_chain(buffer), a:file, 1)
		for file in altlist
			call s:keep_alt(file, altlist)
		endfor
	endif
	return altlist
endfunction

function! s:ask_file(file, mode)
	if a:mode == 1
		let altlist = s:alternate_list(a:file)
	else
		let altlist = s:find_files(s:groups_chain(bufnr(a:file)), a:file, a:mode)
	endif
	if empty(altlist)
		echo 'No alternate files'
		return ''
	endif
	let prompt = [ 'Select file:' ]
	let i = 0
	let N = len(altlist)
	let current = index(altlist, a:file)
	while i < N
		let file = altlist[i]
		if i == current
			let line = '[' . (i + 1) . '] '
		else
			let line = (filereadable(file) ? '+' : ' ') . (i + 1) . ': '
		endif
		let line .= fnamemodify(file, ':~:.')
		call add(prompt, line)
		let i += 1
	endwhile
	let i = inputlist(prompt) - 1
	return i >= 0 && i < N ? altlist[i] : ''
endfunction
" }}}

function! alternate#switch(file, count, action)
	let file = fnamemodify(expand(a:file), ':p')

	if a:count
		let altlist = s:alternate_list(file)
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
		let altfile = s:alternate_file(file)
		if empty(altfile) || file ==# altfile
			echo 'No alternate file'
			return
		endif
	endif

	let altbuf = bufnr(altfile)
	call s:switch_file(altbuf, altfile, a:action)
	call s:keep_alt(altfile, file)
	call s:keep_alt(file, altfile)
	if altbuf == -1 && exists('l:altlist')
		call s:keep_alt(altfile, altlist)
	endif
endfunction

function! alternate#next(file, count, action)
	let file = expand(a:file)
	let file = fnamemodify(file, ':p')

	let altlist = s:alternate_list(file)
	let index = index(altlist, file)
	if index >= 0
		let len = len(altlist)
		let index = (index + a:count) % len
		if index < 0
			let index += len
		endif
	endif
	if index < 0
		echo 'No alternate file'
		return
	endif
	let altfile = altlist[index]
	if file ==# altfile
		return
	endif

	let altbuf = bufnr(altfile)
	call s:switch_file(altbuf, altfile, a:action)
	call s:keep_alt(altfile, file)
	call s:keep_alt(file, altfile)
	if altbuf == -1
		call s:keep_alt(altfile, altlist)
	endif
endfunction

function! alternate#list(file, action, mode)
	let file = expand(a:file)
	let file = fnamemodify(file, ':p')

	let altfile = s:ask_file(file, a:mode)
	if empty(altfile)
		return
	endif

	let altbuf = bufnr(altfile)
	call s:switch_file(altbuf, altfile, a:action)
	call s:keep_alt(altfile, file)
	call s:keep_alt(file, altfile)
endfunction

" vim:ts=4 sw=4 noet:
