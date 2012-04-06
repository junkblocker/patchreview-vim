" Author        : Manpreet Singh < junkblocker@yahoo.com >    " {{{
" Copyright     : 2006-2012 by Manpreet Singh
" License       : This file is placed in the public domain.
"                 No warranties express or implied. Use at your own risk.
"}}}
let s:PRemote = {}
let s:monotone = {}

function! s:monotone.Detect() " {{{
  return isdirectory('_MTN')
endfunction
" }}}

function! s:monotone.GetDiff() " {{{
  let l:diff = s:PRemote.GenDiff('mtn diff --unified')
  return {'diff': 0, 'diff': l:diff}
endfunction
" }}}

function! patchreview#monotone#register(remote) "{{{
  let s:PRemote = a:remote
  return s:monotone
endfunction
" }}}

" vim: set et fdl=99 fdm=marker fenc= ff=unix ft=vim sts=0 sw=2 ts=2 tw=79 nowrap :

