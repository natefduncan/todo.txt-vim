" File:        todo.txt.vim
" Description: Todo.txt filetype detection
" Author:      Leandro Freitas <freitass@gmail.com>
" License:     Vim license
" Website:     http://github.com/freitass/todo.txt-vim
" Version:     0.4

" Export Context Dictionary for unit testing {{{1
function! s:get_SID()
    return matchstr(expand('<sfile>'), '<SNR>\d\+_')
endfunction
let s:SID = s:get_SID()
delfunction s:get_SID

function! todo#txt#__context__()
    return { 'sid': s:SID, 'scope': s: }
endfunction

" Functions {{{1
function! s:get_current_date()
    return strftime('%Y-%m-%d')
endfunction

" Sub-tasks {{{1
" A sub-task is an indented line that follows a top-level (non-indented)
" line. Only one level of nesting is supported. An indented line with no
" top-level line above it (i.e. at the very top of the file) is an orphan and
" is treated as an ordinary task.
let s:SUBTASK_SEP = ' ' . nr2char(1)

function! s:is_indented(lnum)
    return getline(a:lnum) =~ '^\s\+\S'
endfunction

" Line number of the parent of a sub-task, or 0 if lnum is not a sub-task.
function! todo#txt#parent(lnum)
    if !s:is_indented(a:lnum)
        return 0
    endif
    let l:l = a:lnum
    while l:l > 1 && s:is_indented(l:l)
        let l:l -= 1
    endwhile
    return s:is_indented(l:l) ? 0 : l:l
endfunction

function! todo#txt#is_subtask(lnum)
    return todo#txt#parent(a:lnum) > 0
endfunction

" Last line of the family (task plus its sub-tasks) lnum belongs to.
function! todo#txt#family_end(lnum)
    let l:top = todo#txt#is_subtask(a:lnum) ? todo#txt#parent(a:lnum) : a:lnum
    let l:end = l:top
    if s:is_indented(l:top)
        return l:end
    endif
    while l:end < line('$') && s:is_indented(l:end + 1)
        let l:end += 1
    endwhile
    return l:end
endfunction

function! todo#txt#family_start(lnum)
    return todo#txt#is_subtask(a:lnum) ? todo#txt#parent(a:lnum) : a:lnum
endfunction

function! s:is_done(lnum)
    return getline(a:lnum) =~# '^\s*[xX]\s'
endfunction

function! todo#txt#add_subtask()
    let l:parent = todo#txt#family_start(line('.'))
    let l:end = todo#txt#family_end(l:parent)
    " Copy the parent's +projects and @contexts into the new sub-task.
    let l:tags = filter(split(getline(l:parent), '\s\+'), 'v:val =~ "^[+@]\\S"')
    let l:text = '  ' . (empty(l:tags) ? '' : ' ' . join(l:tags, ' '))
    call append(l:end, l:text)
    call cursor(l:end + 1, 3)
    startinsert
endfunction

function! todo#txt#prepend_date()
    " Insert the date after the indentation. Uses setline() rather than
    " :normal so that closed folds don't get in the way.
    let l:lnum = line('.')
    call setline(l:lnum, substitute(getline(l:lnum), '^\(\s*\)', '\=submatch(1) . s:get_current_date() . " "', ''))
endfunction

function! todo#txt#replace_date()
    let current_line = getline('.')
    if (current_line =~ '^\s*\(([a-zA-Z]) \)\?\d\{2,4\}-\d\{2\}-\d\{2\} ') &&
                \ exists('g:todo_existing_date') && g:todo_existing_date == 'n'
        return
    endif
    " setline() keeps the indentation of sub-tasks and ignores closed folds.
    let l:lnum = line('.')
    call setline(l:lnum, substitute(current_line,
                \ '^\(\s*\)\(([a-zA-Z]) \)\?\(\d\{2,4\}-\d\{2\}-\d\{2\} \)\?',
                \ '\=submatch(1) . submatch(2) . s:get_current_date() . " "', ''))
endfunction

" Operates on explicit line numbers with setline(): ex commands without a
" range (e.g. :s) and :normal act on a whole closed fold.
function! s:mark_line_as_done(lnum)
    let l:line = substitute(getline(a:lnum), '^\(\s*\)(\w)\s\+', '\1', '')
    let l:line = substitute(l:line, '^\(\s*\)', '\=submatch(1) . "x " . s:get_current_date() . " "', '')
    call setline(a:lnum, l:line)
endfunction

function! todo#txt#mark_as_done()
    let l:lnum = line('.')
    " A sub-task that is already done is left alone, so that marking a range
    " that includes a parent and its children doesn't mark them twice.
    if todo#txt#is_subtask(l:lnum) && s:is_done(l:lnum)
        return
    endif
    call s:mark_line_as_done(l:lnum)
    " Completing a parent completes its open sub-tasks.
    if !todo#txt#is_subtask(l:lnum)
        for l:child in range(l:lnum + 1, todo#txt#family_end(l:lnum))
            if !s:is_done(l:child)
                call s:mark_line_as_done(l:child)
            endif
        endfor
    endif
endfunction

function! todo#txt#mark_all_as_done()
    :g!/^\s*x /:call todo#txt#mark_as_done()
endfunction

function! s:append_to_file(file, lines)
    let l:lines = []

    " Place existing tasks in done.txt at the beggining of the list.
    if filereadable(a:file)
        call extend(l:lines, readfile(a:file))
    endif

    " Append new completed tasks to the list.
    call extend(l:lines, a:lines)

    " Write to file.
    call writefile(l:lines, a:file)
endfunction

function! todo#txt#remove_completed()
    " Check if we can write to done.txt before proceeding.

    let l:target_dir = expand('%:p:h')
    let l:todo_file = expand('%:p')
    " Check for user-defined g:todo_done_filename
    if exists("g:todo_done_filename")
        let l:todo_done_filename = g:todo_done_filename
    elseif expand('%:t') == 'Todo.txt'
        let l:todo_done_filename = 'Done.txt'
    else
        let l:todo_done_filename = 'done.txt'
    endif
    let l:done_file = substitute(substitute(l:todo_file, 'todo.txt$', l:todo_done_filename, ''), 'Todo.txt$', l:todo_done_filename, '')
    if !filewritable(l:done_file) && !filewritable(l:target_dir)
        echoerr "Can't write to file '" . l:todo_done_filename . "'"
        return
    endif

    " Move completed top-level tasks to done.txt together with their
    " sub-tasks (keeping the indentation). A family is only moved when the
    " parent and all of its sub-tasks are done. A completed sub-task whose
    " parent is still open stays where it is.
    let l:completed = []
    let l:lnum = 1
    " Ex ranges are extended to cover closed folds, so turn folding off while
    " deleting lines.
    let l:foldenable = &l:foldenable
    setlocal nofoldenable
    while l:lnum <= line('$')
        let l:end = todo#txt#family_end(l:lnum)
        let l:all_done = 1
        for l:l in range(l:lnum, l:end)
            if !s:is_done(l:l)
                let l:all_done = 0
            endif
        endfor
        if l:all_done
            call extend(l:completed, getline(l:lnum, l:end))
            silent execute l:lnum . ',' . l:end . 'delete _'
        else
            let l:lnum = l:end + 1
        endif
    endwhile
    let &l:foldenable = l:foldenable
    call s:append_to_file(l:done_file, l:completed)
endfunction

" Sorting {{{1
" Sorting keeps sub-tasks under their parent: every family is temporarily
" joined into a single line, the lines are sorted, and the families are split
" again.
function! s:join_families(first, last)
    let l:out = []
    for l:lnum in range(a:first, a:last)
        if todo#txt#is_subtask(l:lnum) && !empty(l:out)
            let l:out[-1] .= s:SUBTASK_SEP . getline(l:lnum)
        else
            call add(l:out, getline(l:lnum))
        endif
    endfor
    call append(a:last, l:out)
    silent execute a:first . ',' . a:last . 'delete _'
    return a:first + len(l:out) - 1
endfunction

function! s:split_families(first, last)
    let l:out = []
    for l:line in getline(a:first, a:last)
        call extend(l:out, split(l:line, s:SUBTASK_SEP, 1))
    endfor
    call append(a:last, l:out)
    silent execute a:first . ',' . a:last . 'delete _'
endfunction

" a:pattern is empty for a plain sort.
function! s:sort_on(first, last, pattern, move_unmatched)
    " Ex ranges are extended to cover closed folds, so turn folding off.
    let l:foldenable = &l:foldenable
    setlocal nofoldenable
    let l:first = todo#txt#family_start(a:first)
    let l:last = s:join_families(l:first, todo#txt#family_end(a:last))
    if empty(a:pattern)
        execute l:first . ',' . l:last . 'sort'
    else
        execute l:first . ',' . l:last . 'sort /' . a:pattern . '/ r'
        if a:move_unmatched
            execute l:first . ',' . l:last . 'g!/' . a:pattern . '/m' . l:last
        endif
    endif
    call s:split_families(l:first, l:last)
    let &l:foldenable = l:foldenable
endfunction

function! todo#txt#sort() range
    call s:sort_on(a:firstline, a:lastline, '', 0)
endfunction

function! todo#txt#sort_by_context() range
    call s:sort_on(a:firstline, a:lastline, '\(^\| \)\zs@[^[:blank:]]\+', 0)
endfunction

function! todo#txt#sort_by_project() range
    call s:sort_on(a:firstline, a:lastline, '\(^\| \)\zs+[^[:blank:]]\+', 0)
endfunction

function! todo#txt#sort_by_date() range
    call s:sort_on(a:firstline, a:lastline, '\d\{2,4\}-\d\{2\}-\d\{2\}', 1)
endfunction

function! todo#txt#sort_by_due_date() range
    call s:sort_on(a:firstline, a:lastline, 'due:\d\{2,4\}-\d\{2\}-\d\{2\}', 1)
endfunction

" Increment and Decrement The Priority
:set nf=octal,hex,alpha

function! todo#txt#prioritize_increase()
    normal! 0f)h
endfunction

function! todo#txt#prioritize_decrease()
    normal! 0f)h
endfunction

function! todo#txt#prioritize_add(priority)
    " Need to figure out how to only do this if the first visible letter in a line is not (
    :call todo#txt#prioritize_add_action(a:priority)
endfunction

function! todo#txt#prioritize_add_action(priority)
    " Keeps the indentation of sub-tasks; setline() ignores closed folds.
    let l:lnum = line('.')
    call setline(l:lnum, substitute(getline(l:lnum), '^\(\s*\)\(([a-zA-Z]) \)\?',
                \ '\=submatch(1) . "(" . a:priority . ") "', ''))
endfunction

" Modeline {{{1
" vim: ts=8 sw=4 sts=4 et foldenable foldmethod=marker foldcolumn=1
