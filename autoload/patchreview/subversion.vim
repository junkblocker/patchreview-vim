" Author        : Manpreet Singh < junkblocker@yahoo.com >    " {{{
" Copyright     : 2006-2012 by Manpreet Singh
" License       : This file is placed in the public domain.
"                 No warranties express or implied. Use at your own risk.
"}}}
let s:PRemote = {}
let s:subversion = {}

function! s:subversion.Detect() " {{{
  return isdirectory('.svn')
endfunction
" }}}

function! s:subversion.GetDiff() " {{{
  let l:diff = s:PRemote.GenDiff('svn diff')
  return {'diff': 0, 'diff': l:diff}
endfunction
" }}}

function! patchreview#subversion#register(remote) "{{{
  let s:PRemote = a:remote
  return s:subversion
endfunction
" }}}

" vim: set et fdl=99 fdm=marker fenc= ff=unix ft=vim sts=0 sw=2 ts=2 tw=79 nowrap :

