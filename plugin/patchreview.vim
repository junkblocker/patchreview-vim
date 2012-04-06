" VIM plugin for doing single, multi-patch or diff code reviews {{{
" Home:  http://www.vim.org/scripts/script.php?script_id=1563

" Version       : 1.0.1 " {{{
" Author        : Manpreet Singh < junkblocker@yahoo.com >
" Copyright     : 2006-2012 by Manpreet Singh
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
" Installing:
"
"   For a quick start, unzip patchreview.zip into your ~/.vim directory and
"   restart Vim.
"
" Details:
"
"   Requirements:
"
"   1) VIM 7.0 or higher built with +diff option.
"
"   2) A gnu compatible patch command installed. This is the standard patch
"      command on Linux, Mac OS X, *BSD, Cygwin or /usr/bin/gpatch on newer
"      Solaris.
"
"   Install:
"
"   1) Extract the zip in your $HOME/.vim or $VIM/vimfiles directory and
"      restart vim. The  directory location relevant to your platform can be
"      seen by running :help add-global-plugin in vim.
"
"   2) Restart vim.
"
"  Configuration:
"
"  Optionally, specify the locations to the patch command in your .vimrc.
"
"      let g:patchreview_patch       = '/path/to/gnu/patch'
"
" Usage:
"
"  Please see :help patchreview or :help diffreview for details.
"
""}}}

" init " {{{
" Enabled only during development
" unlet! g:loaded_patchreview
" unlet! g:patchreview_patch
" let g:patchreview_patch = 'patch'

if &cp || (! exists('g:patchreview_debug') && exists('g:loaded_patchreview'))
  finish
endif
let g:loaded_patchreview="1.0.1"
if v:version < 700
  echomsg 'patchreview: You need at least Vim 7.0'
  finish
endif
if ! has('diff')
  call confirm('patchreview.vim plugin needs (G)VIM built with +diff support to work.')
  finish
endif
" }}}

" End user commands                                                         "{{{
"============================================================================
" :PatchReview
command! -nargs=+ -complete=file PatchReview        unlet! g:patchreview_persist | call patchreview#PatchReview (<f-args>)
command! -nargs=+ -complete=file PatchReviewPersist let g:patchreview_persist=1  | call patchreview#PatchReview (<f-args>)

" :ReversePatchReview
command! -nargs=+ -complete=file ReversePatchReview        unlet! g:patchreview_persist | call patchreview#ReversePatchReview (<f-args>)
command! -nargs=+ -complete=file ReversePatchReviewPersist let g:patchreview_persist=1  | call patchreview#ReversePatchReview (<f-args>)

" :DiffReview
command! -nargs=* -complete=file DiffReview        unlet! g:patchreview_persist | call patchreview#DiffReview(<f-args>)
command! -nargs=* -complete=file DiffReviewPersist let g:patchreview_persist=1  | call patchreview#DiffReview(<f-args>)
"}}}

"}}}
" modeline
" vim: set et fdl=1 fdm=marker fenc=latin ff=unix ft=vim sw=2 sts=0 ts=2 tw=78 nowrap :
