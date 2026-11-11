" File:        todo.txt.vim
" Description: Todo.txt filetype detection
" Author:      Leandro Freitas <freitass@gmail.com>
" License:     Vim license
" Website:     http://github.com/freitass/todo.txt-vim
" Version:     0.4

" Save context {{{1
let s:save_cpo = &cpo
set cpo&vim

" General options {{{1
" Some options lose their values when window changes. They will be set every
" time this script is invocated, which is whenever a file of this type is
" created or edited.
setlocal textwidth=0
setlocal wrapmargin=0

" Mappings {{{1
" Sort tasks {{{2
nnoremap <script> <silent> <buffer> <localleader>s :%call todo#txt#sort()<CR>
vnoremap <script> <silent> <buffer> <localleader>s :call todo#txt#sort()<CR>
nnoremap <script> <silent> <buffer> <localleader>s@ :%call todo#txt#sort_by_context()<CR>
vnoremap <script> <silent> <buffer> <localleader>s@ :call todo#txt#sort_by_context()<CR>
nnoremap <script> <silent> <buffer> <localleader>s+ :%call todo#txt#sort_by_project()<CR>
vnoremap <script> <silent> <buffer> <localleader>s+ :call todo#txt#sort_by_project()<CR>
nnoremap <script> <silent> <buffer> <localleader>sd :%call todo#txt#sort_by_date()<CR>
vnoremap <script> <silent> <buffer> <localleader>sd :call todo#txt#sort_by_date()<CR>
nnoremap <script> <silent> <buffer> <localleader>sdd :%call todo#txt#sort_by_due_date()<CR>
vnoremap <script> <silent> <buffer> <localleader>sdd :call todo#txt#sort_by_due_date()<CR>

" Change priority {{{2
nnoremap <script> <silent> <buffer> <localleader>j :call todo#txt#prioritize_increase()<CR>
vnoremap <script> <silent> <buffer> <localleader>j :call todo#txt#prioritize_increase()<CR>
nnoremap <script> <silent> <buffer> <localleader>k :call todo#txt#prioritize_decrease()<CR>
vnoremap <script> <silent> <buffer> <localleader>k :call todo#txt#prioritize_decrease()<CR>
nnoremap <script> <silent> <buffer> <localleader>a :call todo#txt#prioritize_add('A')<CR>
vnoremap <script> <silent> <buffer> <localleader>a :call todo#txt#prioritize_add('A')<CR>
nnoremap <script> <silent> <buffer> <localleader>b :call todo#txt#prioritize_add('B')<CR>
vnoremap <script> <silent> <buffer> <localleader>b :call todo#txt#prioritize_add('B')<CR>
nnoremap <script> <silent> <buffer> <localleader>c :call todo#txt#prioritize_add('C')<CR>
vnoremap <script> <silent> <buffer> <localleader>c :call todo#txt#prioritize_add('C')<CR>

" Insert date {{{2
inoremap <script> <silent> <buffer> date<Tab> <C-R>=strftime("%Y-%m-%d")<CR>
nnoremap <script> <silent> <buffer> <localleader>d :call todo#txt#replace_date()<CR>
vnoremap <script> <silent> <buffer> <localleader>d :call todo#txt#replace_date()<CR>

" Mark done {{{2
nnoremap <script> <silent> <buffer> <localleader>x :call todo#txt#mark_as_done()<CR>
vnoremap <script> <silent> <buffer> <localleader>x :call todo#txt#mark_as_done()<CR>

" Add sub-task {{{2
nnoremap <script> <silent> <buffer> <localleader>o :call todo#txt#add_subtask()<CR>

" Mark all done {{{2
nnoremap <script> <silent> <buffer> <localleader>X :call todo#txt#mark_all_as_done()<CR>

" Remove completed {{{2
nnoremap <script> <silent> <buffer> <localleader>D :call todo#txt#remove_completed()<CR>

" Folding {{{1
" Options {{{2
setlocal foldmethod=expr
setlocal foldexpr=s:todo_fold_level(v:lnum)
setlocal foldtext=s:todo_fold_text()

" s:todo_fold_level(lnum) {{{2
function! s:todo_fold_level(lnum)
    " Completed tasks (together with their sub-tasks) are folded into one
    " fold. An open task that has sub-tasks is folded together with them.
    " Everything else doesn't fold.
    let l:group = s:todo_fold_group(a:lnum)
    if l:group == ''
        return 0
    endif
    " A fold of open tasks starts at its parent line. A fold of completed
    " tasks starts wherever the previous line is not completed.
    if l:group == 'family'
        return todo#txt#is_subtask(a:lnum) ? 1 : '>1'
    endif
    return (a:lnum > 1 && s:todo_fold_group(a:lnum - 1) == 'family') ? '>1' : 1
endfunction

" Returns 'done', 'family' (an open task with sub-tasks) or ''.
function! s:todo_fold_group(lnum)
    let l:top = todo#txt#family_start(a:lnum)
    if getline(l:top) =~# '^\s*[xX]\s.\+$'
        return 'done'
    elseif todo#txt#family_end(l:top) > l:top
        return 'family'
    endif
    return ''
endfunction

" s:todo_fold_text() {{{2
function! s:todo_fold_text()
    let l:count = v:foldend - v:foldstart + 1
    if getline(v:foldstart) =~# '^\s*[xX]\s'
        " '+- N Completed tasks'
        return '+' . v:folddashes . ' ' . l:count . ' Completed tasks '
    endif
    " '+- <parent task> (N sub-tasks)'
    return '+' . v:folddashes . ' ' . getline(v:foldstart)
                \ . ' (' . (l:count - 1) . ' sub-tasks) '
endfunction

" Restore context {{{1
let &cpo = s:save_cpo
" Modeline {{{1
" vim: ts=8 sw=4 sts=4 et foldenable foldmethod=marker foldcolumn=1
