" Standalone sub-task tests (no vim-unittest needed). Run from the repo root:
"   vim -u NONE -N -es -S test/subtask_test.vim
set nocompatible
let &runtimepath = getcwd() . ',' . &runtimepath
filetype plugin on
let maplocalleader = '\'
let s:fail = 0
let s:TODAY = strftime('%Y-%m-%d')

function! s:load(lines)
    enew!
    set filetype=todo
    call setline(1, a:lines)
    call cursor(1, 1)
endfunction

function! s:check(name, expected)
    let l:got = getline(1, '$')
    if l:got !=# a:expected
        let s:fail += 1
        call add(g:out, 'FAIL ' . a:name . "\n  expected: " . string(a:expected) . "\n  got:      " . string(l:got))
    else
        call add(g:out, 'ok   ' . a:name)
    endif
endfunction

let g:out = []

call s:load(['(B) b', '  s1', '  s2', '(A) a', '  s3'])
call cursor(1, 1) | call todo#txt#mark_as_done()
call s:check('done parent completes children',
      \ ['x ' . s:TODAY . ' b', '  x ' . s:TODAY . ' s1', '  x ' . s:TODAY . ' s2', '(A) a', '  s3'])

call s:load(['p', '  s1'])
call cursor(2, 1) | call todo#txt#mark_as_done()
call s:check('done sub-task only', ['p', '  x ' . s:TODAY . ' s1'])

call s:load(['(B) b', '  s1', '(A) a', '  s2'])
%call todo#txt#sort()
call s:check('sort keeps families', ['(A) a', '  s2', '(B) b', '  s1'])

call s:load(['b +p', '  s1', 'a +o', '  s2'])
%call todo#txt#sort_by_project()
call s:check('sort by project keeps families', ['a +o', '  s2', 'b +p', '  s1'])

call s:load(['t +p @c', '  s1'])
call cursor(1, 1) | call todo#txt#add_subtask()
call s:check('add sub-task copies tags', ['t +p @c', '  s1', '   +p @c'])
stopinsert

call s:load(['t +p', '  s1'])
call cursor(2, 1) | call todo#txt#add_subtask()
call s:check('add sub-task from sub-task is a sibling', ['t +p', '  s1', '   +p'])
stopinsert

call s:load(['t', '  s1'])
call cursor(2, 1) | call todo#txt#replace_date()
call s:check('replace_date keeps indent', ['t', '  ' . s:TODAY . ' s1'])

call s:load(['t', '  2015-01-01 s1'])
call cursor(2, 1) | call todo#txt#replace_date()
call s:check('replace_date replaces existing', ['t', '  ' . s:TODAY . ' s1'])

call s:load(['t', '  s1'])
call cursor(2, 1) | call todo#txt#prepend_date()
call s:check('prepend_date keeps indent', ['t', '  ' . s:TODAY . ' s1'])

call s:load(['t', '  s1'])
call cursor(2, 1) | call todo#txt#prioritize_add('B')
call s:check('priority keeps indent', ['t', '  (B) s1'])
call cursor(2, 1) | call todo#txt#prioritize_add('C')
call s:check('priority replaced keeps indent', ['t', '  (C) s1'])

call s:load(['t', '  s1'])
call cursor(1, 1) | call todo#txt#prioritize_add('A')
call s:check('priority on closed-fold parent only touches parent', ['(A) t', '  s1'])

" Archive
let s:dir = tempname() | call mkdir(s:dir)
let s:file = s:dir . '/todo.txt'
call writefile(['x d', '  x d1', 'o', '  x o1', 'x e'], s:file)
set hidden
execute 'edit! ' . s:file
set filetype=todo
call todo#txt#remove_completed()
call s:check('archive only fully done families', ['o', '  x o1'])
if filereadable(s:dir . '/done.txt')
    let s:done = readfile(s:dir . '/done.txt')
    if s:done !=# ['x d', '  x d1', 'x e']
        let s:fail += 1 | call add(g:out, 'FAIL done.txt: ' . string(s:done))
    else
        call add(g:out, 'ok   done.txt keeps indent')
    endif
else
    let s:fail += 1 | call add(g:out, 'FAIL no done.txt')
endif

call add(g:out, s:fail ? s:fail . ' FAILED' : 'ALL PASSED')
call writefile(g:out, '/dev/stdout')
execute (s:fail ? 'cquit' : 'qall!')
