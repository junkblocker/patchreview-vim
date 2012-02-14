" VIM plugin for doing single, multi-patch or diff code reviews {{{
" Home:  http://www.vim.org/scripts/script.php?script_id=1563

" Version       : 0.4 " {{{
" Author        : Manpreet Singh < junkblocker@yahoo.com >
" Copyright     : 2006-2012 by Manpreet Singh
" License       : This file is placed in the public domain.
"                 No warranties express or implied. Use at your own risk.
"
" Changelog :
"
"   0.4 - Added wiggle support
"       - Added ReversePatchReview command
"       - Handle paths with special characters in them
"       - Remove patchutils use completely as we can do more with the pure
"         vim version
"       - Show diff if rejections but partially applied
"       - Added patchreview_pre/postfunc for long postreview jobs
"
"   0.3.2 - Some diff extraction fixes and behavior improvement.
"
"   0.3.1 - Do not open the status buffer in all tabs.
"
"   0.3 - Added git diff support
"       - Added some error handling for open files by opening them in read
"         only mode
"
"   0.2.2 - Security fixes by removing custom tempfile creation
"         - Removed need for DiffReviewCleanup/PatchReviewCleanup
"         - Better command execution error detection and display
"         - Improved diff view and folding by ignoring modelines
"         - Improved tab labels display
"
"   0.2.1 - Minor temp directory autodetection logic and cleanup
"
"   0.2 - Removed the need for filterdiff by implementing it in pure vim script
"       - Added DiffReview command for reverse (changed repository to
"         pristine state) reviews.
"         (PatchReview does pristine repository to patch review)
"       - DiffReview does automatic detection and generation of diffs for
"         various Source Control systems
"       - Skip load if VIM 7.0 or higher unavailable
"
"   0.1 - First released
"}}}

" TODO {{{
" 1) git staged support?
" }}}
"
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

if &cp
  finish
endif
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
command! -nargs=* -complete=file PatchReview call patchreviewlib#PatchReview (<f-args>)

" :ReversePatchReview
command! -nargs=* -complete=file ReversePatchReview call patchreviewlib#ReversePatchReview (<f-args>)

" :DiffReview
command! -nargs=0 DiffReview call patchreviewlib#DiffReview()
"}}}


" modeline
" vim: set et fdl=1 fdm=marker fenc=latin ff=unix ft=vim sw=2 sts=0 ts=2 textwidth=78 nowrap :
