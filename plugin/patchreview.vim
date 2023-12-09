" VIM plugin for doing single, multi-patch or diff code reviews {{{
" Home:     https://github.com/junkblocker/patchreview-vim
" vim.org:  http://www.vim.org/scripts/script.php?script_id=1563
" Version       : 2.1.0 " {{{
" Author        : Manpreet Singh < junkblocker@yahoo.com >
" Copyright     : 2006-2020 by Manpreet Singh
" License       : This file is placed in the public domain.
"                 No warranties express or implied. Use at your own risk.
"
"}}}
" Documentation:                                                         "{{{
" ===========================================================================
" This plugin allows single or multiple, patch or diff based code reviews to
" be easily done in VIM. VIM has :diffpatch command to do single file reviews
" but a) can not handle patch files containing multiple patches or b) do
" automated diff generation for various version control systems. This plugin
" attempts to provide those functionalities. It opens each changed / added or
" removed file diff in new tabs.
"
" Requirements:
"
"   1) VIM 7.0 or higher built with +diff option.
"
"   2) A gnu compatible patch command installed. This is the standard patch
"      command on Linux, Mac OS X, *BSD, Cygwin or /usr/bin/gpatch on newer
"      Solaris.
"
" Usage:
"
"  Please see :help patchreview, :help diffreview or :help reversepatchreview
"  for details.
"
""}}}
" init " {{{
" Enabled only during development
" unlet! g:loaded_patchreview
" unlet! g:patchreview_patch
" let g:patchreview_patch = 'patch'

if &cp || ((! exists('g:patchreview_debug') || g:patchreview_debug == 0) && exists('g:loaded_patchreview'))
  finish
endif
let g:loaded_patchreview="2.1.0"
if v:version < 700
  echomsg 'patchreview: You need at least Vim 7.0'
  finish
endif
if ! has('diff')
  call confirm('patchreview.vim plugin needs (G)VIM built with +diff support to work.')
  finish
endif
" }}}
function! <SID>wrap_event_ignore(f, persist, ...)
  let l:syn = exists("syntax_on") || exists("syntax_manual")
  try
    let l:eventignore = &eventignore
    if get(g:, 'patchreview_ignore_events', 1)
      set eventignore=all
    endif
    if a:persist
      let g:patchreview_persist = 1
    else
      unlet! g:patchreview_persist
    endif
    let l:call_args = [] + deepcopy(a:000)
    call call(a:f, l:call_args)
  finally
    let &eventignore=l:eventignore
    if l:syn
      syn on
    endif
  endtry
endfunction
" End user commands                                                         "{{{
"============================================================================
" :PatchReview
command! -nargs=+ -complete=file PatchReview        call s:wrap_event_ignore('patchreview#patchreview', 0, <f-args>)
command! -nargs=+ -complete=file PatchReviewPersist call s:wrap_event_ignore('patchreview#patchreview', 1, <f-args>)

" :ReversePatchReview
command! -nargs=+ -complete=file ReversePatchReview        call s:wrap_event_ignore('patchreview#reverse_patchreview', 0, <f-args>)
command! -nargs=+ -complete=file ReversePatchReviewPersist call s:wrap_event_ignore('patchreview#reverse_patchreview', 1, <f-args>)

" :DiffReview
command! -nargs=* -complete=file DiffReview        call s:wrap_event_ignore('patchreview#diff_review', 0, <f-args>)
command! -nargs=* -complete=file DiffReviewPersist call s:wrap_event_ignore('patchreview#diff_review', 1, <f-args>)
"}}}
" vim: set et fdl=1 fdm=marker fenc= ff=unix ft=vim sw=2 sts=0 ts=2 tw=79 nowrap :
"}}}
